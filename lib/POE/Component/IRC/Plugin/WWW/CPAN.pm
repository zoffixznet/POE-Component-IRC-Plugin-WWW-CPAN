package POE::Component::IRC::Plugin::WWW::CPAN;

use warnings;
use strict;

our $VERSION = '0.0101';

use base 'POE::Component::IRC::Plugin::BasePoCoWrap';
use POE::Component::WWW::CPAN;

sub _make_default_args {
    return (
        response_event   => 'irc_cpan_result',
        trigger          => qr/^cpan\s+(?=\S+)/i,
        mode             => 'all',
        n                => 10,
        line_length      => 350,
        's'              => 1,
    );
}

sub _make_poco {
    return POE::Component::WWW::CPAN->spawn(
        debug => shift->{debug},
    );
}

sub _make_response_message {
    my ( $self, $in_ref ) = @_;

    return $self->_prepare_response( $in_ref );
}

sub _make_response_event {
    my ( $self, $in_ref ) = @_;

    return {
        results => $self->_prepare_response( $in_ref ),
        map { $_ => $in_ref->{"_$_"} }
            qw( who channel  message  type ),
    };
}

sub _prepare_response {
    my ( $self, $in_ref ) = @_;

    if ( $in_ref->{_command} eq 'query' ) {
        my $result = $in_ref->{result}{module}[0];
        defined $result
            or return [ 'No matches' ];

        eval {
            $result->{author}   = uc substr $result->{author}{link}, 24
                if ref $result->{author};

            $result->{author} =~ s/\W+//g;

            for ( @$result{ qw/released description/ } ) {
                s/^\s+|\s+$//g;
                s/\s{2,}/ /g;
            }
            unless ( defined $result->{version} ) {
                ( $result->{version} ) = $result->{link} =~ /([\d.]{3,})/;
            }
            $result->{link} = "http://search.cpan.org/perldoc?$result->{name}";
        };
        if ( $@ ) {
            return [ "Error: $@" ];
        }
    
        return [
            qq|$result->{name} v$result->{version} by $result->{author}|
            . qq| "$result->{description}" [ $result->{link} ]|
        ];
    }
    else {
        my @lines;
        my @current_line;
        my $length = 0;
        foreach ( map $_->{name}, @{ $in_ref->{result}{module} } ) {
            $length += 1 + length;
            if ( $length > $self->{line_length} ) {
                push @lines, join ' ', @current_line;
                @current_line = ();
                $length = 0;
            }
            else {
                push @current_line, $_;
            }
        }
        push @lines, join ' ', @current_line;
        return \@lines;
    }
}

sub _make_poco_call {
    my $self = shift;
    my $data_ref = shift;

    my ( $command, $query ) = split ' ', delete $data_ref->{what}, 2;

    unless ( defined $query ) {
        $query = $command;
        $command = 'query';
    }

    $command = lc $command;

    unless ( $command eq 'search' or $command eq 'query' ) {
        $command = 'query';
    }

    $self->{poco}->search( {
            event       => '_poco_done',
            query       => $query,
            mode        => $self->{mode},
            's'         => $self->{'s'},
            n           => ($command eq 'query' ? 1 : $self->{n}),
            _command    => $command,
            map +( "_$_" => $data_ref->{$_} ),
                keys %$data_ref,
        }
    );
}

1;
__END__

=head1 NAME

POE::Component::IRC::Plugin::WWW::CPAN - access http://search.cpan.org/ from IRC

=head1 SYNOPSIS

    use strict;
    use warnings;

    use POE qw(Component::IRC  Component::IRC::Plugin::WWW::CPAN);

    my $irc = POE::Component::IRC->spawn(
        nick        => 'CPAN_bot',
        server      => 'irc.freenode.net',
        port        => 6667,
        ircname     => 'CPAN bot',
    );

    POE::Session->create(
        package_states => [
            main => [ qw(_start irc_001) ],
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


    Zoffix> cpan_bot, cpan WWW::CPAN
    <cpan_bot> WWW::CPAN v0.011 by FERREIRA "CPAN as a web service" [
               http://search.cpan.org/perldoc?WWW::CPAN ]

    <Zoffix> cpan_bot, cpan search WWW::CPAN
    <cpan_bot> WWW::CPAN POE::Component::WWW::CPAN cpanq App::WWW::CPAN

=head1 DESCRIPTION

This module is a L<POE::Component::IRC> plugin which uses
L<POE::Component::IRC::Plugin> for its base. It provides interface to
to L<http://search.cpan.org/> from IRC.
It accepts input from public channel events, C</notice> messages as well
as C</msg> (private messages); although that can be configured at will.

The plugin has two "modes" of functionality. First mode
is displaying information about
specified module (this will be the first module found on
L<http://search.cpan.org/> matching the input). The second mode, which
is referred to as B<search command> throughout this documentation will
list the names of modules from L<http://search.cpan.org/> which match
your input. The C<search command> is triggered by starting your
search query with C<'search '> word (which must be separated from
the query itself by white-space).

See the end of SYNOPSYS section above for usage examples.

=head1 CONSTRUCTOR

=head2 C<new>

    # plain and simple
    $irc->plugin_add(
        'cpan' => POE::Component::IRC::Plugin::WWW::CPAN->new
    );

    # juicy flavor
    $irc->plugin_add(
        'cpan' =>
            POE::Component::IRC::Plugin::WWW::CPAN->new(
                mode             => 'all',
                n                => 10,
                s                => 1,
                line_length      => 350,
                auto             => 1,
                response_event   => 'irc_cpan_result',
                banned           => [ qr/aol\.com$/i ],
                addressed        => 1,
                root             => [ qr/mah.net$/i ],
                trigger          => qr/^cpan\s+(?=\S+\s+\S+)/i,
                listen_for_input => [ qw(public notice privmsg) ],
                eat              => 1,
                debug            => 0,
            )
    );

The C<new()> method constructs and returns a new
C<POE::Component::IRC::Plugin::WWW::CPAN> object suitable to be
fed to L<POE::Component::IRC>'s C<plugin_add> method. The constructor
takes a few arguments, but I<all of them are optional>. The possible
arguments/values are as follows:

=head3 C<mode>

    ->new( mode => 'all' );

B<Optional>. Specifies the mode on which the plugin's search will operate.
Possible values are C<all>, C<module>, C<dist> and C<author>. The same
as on L<http://search.cpan.org/>. B<Defaults to:> C<all>.

=head3 C<n>

    ->new( n => 10 );

B<Optional>. Specifies how many results to retrieve when the C<'search'>
command is issued. As a value takes a positive integer between 1 and 100
(inclusive). B<Defaults to:> C<10>

=head3 C<s>

    ->new( s => 1 );

B<Optional>. Applies only to the C<'search'> command.
Specifies from which page of results
on L<http://search.cpan.org/> to retrive the results. You definitely
would want to leave it at its default value. B<Defaults to:> C<1>

=head3 C<line_length>

    line_length => 350,

B<Optional>. Applies only to the C<'search'> command. Specifies after
how many characters to break up the lines (as for them not to get cut
off). The actual number of characters may be less than the number specified
as the plugin will not split up the names of modules on several lines.
B<Defaults to:> C<350>

=head3 C<auto>

    ->new( auto => 0 );

B<Optional>. Takes either true or false values, specifies whether or not
the plugin should auto respond to requests. When the C<auto>
argument is set to a true value plugin will respond to the requesting
person with the results automatically. When the C<auto> argument
is set to a false value plugin will not respond and you will have to
listen to the events emited by the plugin to retrieve the results (see
EMITED EVENTS section and C<response_event> argument for details).
B<Defaults to:> C<1>.

=head3 C<response_event>

    ->new( response_event => 'event_name_to_recieve_results' );

B<Optional>. Takes a scalar string specifying the name of the event
to emit when the results of the request are ready. See EMITED EVENTS
section for more information. B<Defaults to:> C<irc_cpan_result>

=head3 C<banned>

    ->new( banned => [ qr/aol\.com$/i ] );

B<Optional>. Takes an arrayref of regexes as a value. If the usermask
of the person (or thing) making the request matches any of
the regexes listed in the C<banned> arrayref, plugin will ignore the
request. B<Defaults to:> C<[]> (no bans are set).

=head3 C<root>

    ->new( root => [ qr/\Qjust.me.and.my.friend.net\E$/i ] );

B<Optional>. As opposed to C<banned> argument, the C<root> argument
B<allows> access only to people whose usermasks match B<any> of
the regexen you specify in the arrayref the argument takes as a value.
B<By default:> it is not specified. B<Note:> as opposed to C<banned>
specifying an empty arrayref to C<root> argument will restrict
access to everyone.

=head3 C<trigger>

    ->new( trigger => qr/^cpan\s+(?=\S+\s+\S+)/i );

B<Optional>. Takes a regex as an argument. Messages matching this
regex will be considered as requests. See also
B<addressed> option below which is enabled by default. B<Note:> the
trigger will be B<removed> from the message, therefore make sure your
trigger doesn't match the actual data that needs to be processed.
B<Defaults to:> C<qr/^cpan\s+(?=\S+\s+\S+)/i>. B<Note:> the optional
C<'search'> command that changed plugin's output B<follows> the C<trigger>
and is not specifiable.

=head3 C<addressed>

    ->new( addressed => 1 );

B<Optional>. Takes either true or false values. When set to a true value
all the public messages must be I<addressed to the bot>. In other words,
if your bot's nickname is C<Nick> and your trigger is
C<qr/^trig\s+/>
you would make the request by saying C<Nick, trig WWW::CPAN>.
When addressed mode is turned on, the bot's nickname, including any
whitespace and common punctuation character will be removed before
matching the C<trigger> (see above). When C<addressed> argument it set
to a false value, public messages will only have to match C<trigger> regex
in order to make a request. Note: this argument has no effect on
C</notice> and C</msg> requests. B<Defaults to:> C<1>

=head3 C<listen_for_input>

    ->new( listen_for_input => [ qw(public  notice  privmsg) ] );

B<Optional>. Takes an arrayref as a value which can contain any of the
three elements, namely C<public>, C<notice> and C<privmsg> which indicate
which kind of input plugin should respond to. When the arrayref contains
C<public> element, plugin will respond to requests sent from messages
in public channels (see C<addressed> argument above for specifics). When
the arrayref contains C<notice> element plugin will respond to
requests sent to it via C</notice> messages. When the arrayref contains
C<privmsg> element, the plugin will respond to requests sent
to it via C</msg> (private messages). You can specify any of these. In
other words, setting C<( listen_for_input => [ qr(notice privmsg) ] )>
will enable functionality only via C</notice> and C</msg> messages.
B<Defaults to:> C<[ qw(public  notice  privmsg) ]>

=head3 C<eat>

    ->new( eat => 0 );

B<Optional>. If set to a false value plugin will return a
C<PCI_EAT_NONE> after
responding. If eat is set to a true value, plugin will return a
C<PCI_EAT_ALL> after responding. See L<POE::Component::IRC::Plugin>
documentation for more information if you are interested. B<Defaults to>:
C<1>

=head3 C<debug>

    ->new( debug => 1 );

B<Optional>. Takes either a true or false value. When C<debug> argument
is set to a true value some debugging information will be printed out.
When C<debug> argument is set to a false value no debug info will be
printed. B<Defaults to:> C<0>.

=head1 EMITED EVENTS

=head2 response_event - C<irc_cpan_result>

The event handler set up to handle the event, name of which you've
specified in the C<response_event> argument to the constructor
(it defaults to C<irc_cpan_result>) will recieve input
every time request is completed. The input will come in a form of a hashref.
The keys/values of that hashref are as follows:

    $VAR1 = {
        'who' => 'Zoffix!n=Zoffix@unaffiliated/zoffix',
        'type' => 'public',
        'channel' => '#zofbot',
        'message' => 'cpan_bot, cpan WWW::CPAN',
        'results' => [
            'WWW::CPAN v0.011 by FERREIRA "CPAN as a web service" [ http://search.cpan.org/perldoc?WWW::CPAN ]'
        ]
    };

=head3 C<results>

    {
        'results' => [
            'WWW::CPAN v0.011 by FERREIRA "CPAN as a web service" [ http://search.cpan.org/perldoc?WWW::CPAN ]'
        ]
    }

The C<result> key will contain an arrayref of messages which are spoken
to the channel/user when C<auto> mode is turned on. If you turn off the
C<auto> mode (see CONSTRUCTOR), this is from where you would fetch
the results of query.

=head3 C<who>

    { 'who' => 'Zoffix!Zoffix@i.love.debian.org', }

The C<who> key will contain the user mask of the user who sent the request.

=head3 C<what>

    { 'what' => 'WWW::CPAN', }

    { 'what' => 'search WWW::CPAN', }

The C<what> key will contain user's message after stripping the C<trigger>
(see CONSTRUCTOR).

=head3 C<message>

    { 'message' => 'cpan_bot, cpan WWW::CPAN' }

The C<message> key will contain the actual message which the user sent; that
is before the trigger is stripped.

=head3 C<type>

    { 'type' => 'public', }

The C<type> key will contain the "type" of the message the user have sent.
This will be either C<public>, C<privmsg> or C<notice>.

=head3 C<channel>

    { 'channel' => '#zofbot', }

The C<channel> key will contain the name of the channel where the message
originated. This will only make sense if C<type> key contains C<public>.

=head1 EXAMPLES

The C<examples/> directory of this distribution contains a sample
"cpan_bot", make sure to change in the code or join the correct
IRC network/channel.

=head1 AUTHOR

Zoffix Znet, C<< <zoffix at cpan.org> >>
(L<http://zoffix.com>, L<http://haslayout.net>)

=head1 BUGS

Please report any bugs or feature requests to C<bug-poe-component-irc-plugin-www-cpan at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=POE-Component-IRC-Plugin-WWW-CPAN>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc POE::Component::IRC::Plugin::WWW::CPAN

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=POE-Component-IRC-Plugin-WWW-CPAN>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/POE-Component-IRC-Plugin-WWW-CPAN>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/POE-Component-IRC-Plugin-WWW-CPAN>

=item * Search CPAN

L<http://search.cpan.org/dist/POE-Component-IRC-Plugin-WWW-CPAN>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2008 Zoffix Znet, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

