#!/usr/bin/env perl

use strict;
use warnings;
our $VERSION = '0.0101';

use lib '../lib';
use POE qw(Component::IRC  Component::IRC::Plugin::WWW::CPAN);

my $irc = POE::Component::IRC->spawn(
    nick        => 'cpan_bot',
    server      => 'irc.freenode.net',
    port        => 6667,
    ircname     => 'CPAN bot',
    plugin_debug => 1,
);

POE::Session->create(
    package_states => [
        main => [ qw(_start irc_001 irc_cpan_result) ],
    ],
);

$poe_kernel->run;

sub _start {
    $irc->yield( register => 'all' );

    $irc->plugin_add(
        'cpan' =>
            POE::Component::IRC::Plugin::WWW::CPAN->new
    );

    $irc->yield( connect => {} );
}

sub irc_001 {
    $_[KERNEL]->post( $_[SENDER] => join => '#zofbot' );
}

sub irc_cpan_result {

    print "Results:\n", join "\n", @{ $_[ARG0]->{results} }, '';
}

=head1 DESCRIPTION

    perl cpan_bot.pl

IRC bot with functionality to search L<http://search.cpan.org/>

See L<POE::Component::IRC::Plugin::WWW::CPAN> for more information

=cut