 #!/usr/bin/perl -w


 use strict;
# my $bool_func = "((S0*B)|((!S0)*A))";
my $bool_func = "gfp_g>=2.5||gfp_g_s>=2.5||gfp_c>=2.5";
(my $perl_expr = $bool_func) =~ s/([a-zA-Z]\w*)/\$printseen{$1}/g;

print "Using perl expression: $perl_expr\n";

my @vars = do {
    my %seen;
    grep !$seen{$_}++, $bool_func =~ /([a-zA-Z]\w*)/g;
};
map { print $_."\n" } @vars;

# $val{$vars[$_]} = ( $assignment >> $_ ) & 1 for 0 .. $#vars;

    my %val = (ch_g_s => 4.9,
               gfp_g_s => 4.5,
               ch_c => 1.4,
               ch_g => 5.2,
               gfp_g => 1.2,
               gfp_c => 0.9);
    my %printseen = (ch_g_s => -0.7,
               gfp_g_s => 0.4,
                ch_c => 1.6,
                ch_g => 2.1,
                gfp_g => 3.1,
                gfp_c => 0.6);


    my $result = eval $perl_expr;

    print join(", ", map { "$_=$printseen{$_}" } keys %printseen), " ==> [ $bool_func ] =$result\n";

__END__

# original code with logic matrix resolved

# my $bool_func = "((S0*B)|((!S0)*A))";
# (my $perl_expr = $bool_func) =~ s/([a-zA-Z]\w*)/\$val{$1}/g;
#
# print "Using perl expression: $perl_expr\n";
#
# my @vars = do {
#     my %seen;
#     grep !$seen{$_}++, $bool_func =~ /([a-zA-Z]\w*)/g;
# };
#
# for my $assignment ( 0 .. (2**@vars)-1 ) {
#     my %val;
#
#     $val{$vars[$_]} = ( $assignment >> $_ ) & 1
#         for 0 .. $#vars;
#
#     my $result = eval $perl_expr;
#
#     print join(", ", map { "$_=$val{$_}" } keys %val),
#           " ==> $bool_func=$result\n";
# }
#
# __END__
# Using perl expression: (($val{S0}*$val{B})|((!$val{S0})*$val{A}))
# A=0, S0=0, B=0 ==> ((S0*B)|((!S0)*A))=0
# A=0, S0=1, B=0 ==> ((S0*B)|((!S0)*A))=0
# A=0, S0=0, B=1 ==> ((S0*B)|((!S0)*A))=0
# A=0, S0=1, B=1 ==> ((S0*B)|((!S0)*A))=1
# A=1, S0=0, B=0 ==> ((S0*B)|((!S0)*A))=1
# A=1, S0=1, B=0 ==> ((S0*B)|((!S0)*A))=0
# A=1, S0=0, B=1 ==> ((S0*B)|((!S0)*A))=1
A=1, S0=1, B=1 ==> ((S0*B)|((!S0)*A))=1