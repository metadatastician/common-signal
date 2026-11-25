#!/usr/bin/env perl
# SPDX-License-Identifier: MPL-2.0
use strict;
use warnings;

# A fresh mint may have no manifests. Keep ecosystems selected by archetype,
# and always drop nix: Dependabot rejects the entire config if it declares nix.
@ARGV >= 2 or die "Usage: $0 <file> <keep...>\n";
my ($path, @ecosystems) = @ARGV;
my %keep = map { $_ => 1 } @ecosystems;
delete $keep{nix};

if (!-f $path) {
    print "  dependabot: $path absent, nothing to prune\n";
    exit 0;
}

open my $input, '<:raw', $path or die "Cannot read $path: $!\n";
my $text = do { local $/; <$input> // '' };
close $input or die "Cannot close $path: $!\n";

# Keep the original formatting. Trailing comments travel with their entry.
my $entry_start = qr/^[ \t]*-[ \t]*package-ecosystem:/m;
my @entries = split /(?=$entry_start)/, $text;
my $head = @entries && $entries[0] !~ $entry_start ? shift @entries : '';
my (@kept, @kept_names, @dropped);
for my $entry (@entries) {
    my ($name) = $entry =~ /package-ecosystem:[ \t]*["']?([A-Za-z-]+)/;
    $name //= '?';
    if ($keep{$name}) {
        push @kept, $entry;
        push @kept_names, $name;
    } else {
        push @dropped, $name;
    }
}

if (!@kept && @dropped) {
    print "  dependabot: refusing to prune every entry; left unchanged\n";
} elsif (!@dropped) {
    print @kept ? "  dependabot: nothing to prune\n"
                : "  dependabot: no ecosystem entries found\n";
} else {
    open my $output, '>:raw', $path or die "Cannot write $path: $!\n";
    print {$output} $head, @kept or die "Cannot write $path: $!\n";
    close $output or die "Cannot close $path: $!\n";
    print '  dependabot: kept ', join(', ', @kept_names),
          ' / dropped ', join(', ', @dropped), "\n";
}
