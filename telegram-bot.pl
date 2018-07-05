#!/usr/bin/perl

use strict;
use warnings;

use DBI;
use JSON;
use Getopt::Long;
use Pod::Usage;
use Scalar::Util qw( looks_like_number );

my $token       = '';
my $verbose     = 0;
my $man         = 0;
my $help        = 0;
my $deals_db    = 'data/deals.db';

GetOptions(
    'token|t=s'     => \$token,
    'verbose|v'     => \$verbose,
    'help|h'        => \$help,
    'man'           => \$man,
) or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitval => 0, -verbose => 2) if $man;

my $dbh = DBI->connect('DBI:SQLite:dbname=data/deals.db', 'sonm', 'sonm',
    { RaiseError => 1 }
) or die $DBI::errstr;

my $latest = 0;

while (1) {
    # Get updates
    my $tg_url = "https://api.telegram.org/bot$token/getUpdates?offset=$latest";
    my $data = `curl -s $tg_url`;
    my $updates = JSON->new->utf8->decode($data);

    if ($updates) {
        unless ($latest) {
            $latest = $updates->{result}->[@{$updates->{result}}-1]
                ->{message}->{date};
        }
        foreach my $upd (@{$updates->{result}}) {
            if ($upd->{message}->{date} <= $latest) {
                next;
            }
            $latest = $upd->{message}->{date};
            my $cmd = $upd->{message}->{text};
            next unless $cmd && $cmd =~ /^\/dm\@{0,1}(.*)$/;
            respond_stats($upd);
        }
    }

    sleep(1);
}

sub respond_stats {
    my ($upd) = @_;

    my $sth = $dbh->prepare('SELECT amount FROM deals ORDER BY timestamp DESC LIMIT 1');
    $sth->execute();
    my ($latest) = $sth->fetchrow_array();
    $sth = $dbh->prepare('SELECT amount FROM deals WHERE ' .
        'timestamp < DATETIME("now", "-1 hour") ORDER BY timestamp DESC LIMIT 1');
    $sth->execute();
    my ($interval_1hour) = $sth->fetchrow_array();
    $sth = $dbh->prepare('SELECT amount FROM deals WHERE ' .
        'timestamp < DATETIME("now", "-1 day") ORDER BY timestamp DESC LIMIT 1');
    $sth->execute();
    my ($interval_1day) = $sth->fetchrow_array();
    $sth = $dbh->prepare('SELECT amount FROM deals WHERE ' .
        'timestamp < DATETIME("now", "-1 week") ORDER BY timestamp DESC LIMIT 1');
    $sth->execute();
    my ($interval_1week) = $sth->fetchrow_array();
    $sth = $dbh->prepare('SELECT amount FROM deals WHERE ' .
        'timestamp < DATETIME("now", "-1 month") ORDER BY timestamp DESC LIMIT 1');
    $sth->execute();
    my ($interval_1month) = $sth->fetchrow_array();
    $sth = $dbh->prepare('SELECT amount FROM deals ORDER BY '.
        'timestamp ASC LIMIT 1');
    $sth->execute();
    my ($interval_all) = $sth->fetchrow_array();

    my $chat_id = $upd->{message}->{chat}->{id};
    my $msg_id  = $upd->{message}->{message_id};
    my $msg  = "Current deals: $latest\n";
       $msg .= '1 hour: ' . inc_dec($latest, $interval_1hour) . "\n";
       $msg .= '1 day: ' . inc_dec($latest, $interval_1day) . "\n";
       $msg .= '1 week: ' . inc_dec($latest, $interval_1week) . "\n";
       $msg .= '1 month: ' . inc_dec($latest, $interval_1month) . "\n";
       $msg .= 'All time: ' . inc_dec($latest, $interval_all);
    my $tg_url = "https://api.telegram.org/bot$token/sendMessage";
    `curl -s -G $tg_url --data-urlencode "text=$msg" --data-urlencode "chat_id=$chat_id" --data-urlencode "reply_to_message_id=$msg_id"`;
    print "Sending message to chat id $chat_id\n" if $verbose;
}

sub inc_dec {
    my ($latest, $old) = @_;

    return "---" unless defined $old;
    return "+0.00%" if $latest == $old;

    if ($latest > $old) {
        my $increase = $latest - $old;
        return '-' . sprintf("%.2f", ($increase / $old * 100)) . '%';
    } else {
        my $decrease = $old - $latest;
        return '-' . sprintf("%.2f", ($decrease / $old * 100)) . '%';
    }
}
__END__

=head1 NAME

telegram-bot.pl - Reports the number of deals and the change to Telegram Chat

=head1 SYNOPSIS

./telegram-bot.pl [options]

 Options:
    --help or -h        Prints help message
    --man               Full documentation
    --token or -t       Your Telegram Bot token
    --verbose or -v     Verbose output

=head1 OPTIONS

=over 8

=item B<--help> or B<-h>

Prints a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<--interval> or B<-i>

The secret token of your Telegram Bot.

=item B<--verbose> or B<-v>

A more verbose output.

=back

=head1 DESCRIPTION

B<telegram-bot.pl> reports the number of deals and the change to Telegram Chat.

=cut
