#!/usr/bin/env perl
# SPDX-License-Identifier: MPL-2.0
use strict;
use warnings;
use Encode qw(decode encode FB_CROAK);
use File::Find qw(find);
use File::Spec;

# Run after placeholder substitution. Only strip HTML comments containing
# the marker; the match cannot cross an earlier comment's terminator, so a
# separate SPDX header survives.
my $marker = 'TEMPLATE INSTRUCTIONS';
my $block = qr/<!--(?:(?!-->).)*?\Q$marker\E(?:(?!-->).)*?-->[ \t]*\n?/s;
my %skip = map { $_ => 1 } qw(.git node_modules .venv target dist);
my $root = File::Spec->canonpath($ARGV[0] // '.');
my @files;

if (-d $root && !grep { $skip{$_} } File::Spec->splitdir($root)) {
    find({
        no_chdir => 1,
        wanted => sub {
            my $path = File::Spec->canonpath($File::Find::name);
            my (undef, undef, $name) = File::Spec->splitpath($path);
            if (-d $path && $skip{$name}) {
                $File::Find::prune = 1;
            } elsif (!-l $path && -f $path) {
                push @files, $path;
            }
        },
    }, $root);
}

my $changed = 0;
for my $path (sort @files) {
    open my $input, '<:raw', $path or next;
    my $bytes = do { local $/; <$input> // '' };
    close $input;
    next if index($bytes, $marker) < 0;
    # Ignore files that were not valid UTF-8, as the original helper did.
    my $text = eval { decode('UTF-8', $bytes, FB_CROAK) };
    next unless defined $text;
    $text =~ s/\r\n?/\n/g;
    next unless $text =~ s/$block//g;
    $text =~ s/\n{3,}/\n\n/g;
    open my $output, '>:raw', $path or die "Cannot write $path: $!\n";
    print {$output} encode('UTF-8', $text) or die "Cannot write $path: $!\n";
    close $output or die "Cannot close $path: $!\n";
    print "  instruction block: stripped from $path\n";
    ++$changed;
}
print $changed ? "  instruction blocks: $changed file(s) cleaned\n"
               : "  instruction blocks: none found\n";
