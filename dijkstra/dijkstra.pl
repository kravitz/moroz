#!/usr/bin/env perl
use strict;
use warnings;
use feature "switch";

sub usage {
    print <<'EOL';
Usage: dijkstra.pl [option]
Reads expression from stdin and writes to stdout
    -h, --help:         Print this message
EOL
}

if (@ARGV == 1) {
    if ($ARGV[0] ~~ ['-h','--help']) {
        usage
    } else {
        print "Error: Unrecognized option\n";
    }
    exit 0;
} elsif (@ARGV > 1) {
    print "Error: Too many arguments\n";
    exit 0;
}

sub ltrim {
    my $string = shift;
    $string =~ s/^[\s"']+//;
    $string;
}

my $input = ltrim(join ' ', <STDIN>);
my $decimals = '\d+';
my $floats = '\d+\.\d+';
my $binops = '[+*\-\/\^]';
my $signs = '[+*\-\/\^\(\)]';

my @tokenbuf;
sub getNextToken {
    if (@tokenbuf) {
        return pop @tokenbuf;
    }
    unless ($input) {
        return "EOF";
    }
    if ($input =~ /^($floats|$decimals|$signs)/) {
        $input = ltrim substr($input, length($1));
        return $1;
    }
    die "Unrecognized token: $input";
}

sub is_operand {
    my $t = getNextToken();
    if ($t ~~ ["+","-"]) {
        is_operand();
    }
    elsif ($t eq "(") {
        is_expression();
        ($t = getNextToken()) eq ")" || die "Parenthesis mismatch, meet $t";
    }
    elsif ($t !~ $floats && $t !~ $decimals) {
        die "Expected operand, meet $t";
    }
}

sub is_expression {
    is_operand();
    my $t = getNextToken();
    if ($t =~ $binops) {
        is_expression();
    }
    elsif ($t ne "EOF") {
        push @tokenbuf, $t;
    }
}

my @stack;

sub getPriority {
    $_ = shift;
    given ($_) {
        when (/\(/) { return 0 ; }
        when (/\)/) { return 1; }
        when (/[+\-]/) { return 2; }
        when (/[*\/]/) { return 3; }
        when (/\^/) { return 4; }
        when (/[mp]/) { return 5; }
    }
}

sub isLeftAssoc {
    $_ = shift;
    if ($_ ~~ ["p","m","^"]) {
        return 0;
    }
    return 1;
} 

sub deobfuscate {
    $_ = shift;
    $_ =~ tr/mp/-+/;
    return $_;
}

my $input_copy = $input;
is_expression();
($input || @tokenbuf) && die "Junk after expression: " . (pop @tokenbuf) . $input;
$input = $input_copy;

my $last_was_operation = 1;
my @outstack;
while (length $input) {
    my $t = getNextToken();
    if ($t !~ $signs) {
        push @outstack, $t;
        $last_was_operation = 0;
        next;
    }
    if ($last_was_operation && $t ~~ ["+","-"]) {
            push @outstack, 0;
            $t =~ tr/-+/mp/;
    } 
    $last_was_operation = 1 unless $t ~~ ["(",")"];
    if (@stack == 0) { 
        push @stack, $t;
        next;
    }
    my $p = getPriority($t);
    while (@stack != 0 && $t ne "(" && (
            (isLeftAssoc($t) && getPriority($stack[-1]) >= $p) ||
            (!isLeftAssoc($t) && getPriority($stack[-1]) > $p))) {
        push @outstack, deobfuscate pop @stack;
    }
    if ($t eq ")") {
        do {
            $_ = deobfuscate pop @stack;
            push @outstack, $_ unless $_ eq "(";
        } until ($_ eq "(");
    } else {
        push(@stack, $t)
    }
}
push @outstack, deobfuscate pop @stack if @stack;

my @calcstack;
foreach my $elm (@outstack) {
    print $elm, ' ';
    if ($elm !~ $signs) {
        push @calcstack, $elm;
    } else {
        my $v2 = pop(@calcstack);
        my $v1 = pop(@calcstack);
        my $res;
        $elm =~ s/\^/**/;
        unless(defined ($res = eval "($v1) $elm ($v2)")) {
            die $@;
        }
        push @calcstack, $res;
    }
}
print "= $calcstack[-1]";

