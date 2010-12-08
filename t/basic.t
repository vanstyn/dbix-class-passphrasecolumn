use strict;
use warnings;
use Test::More;

use FindBin;
use lib "$FindBin::Bin/lib";

use TestSchema;
use SQL::Translator;
use Authen::Passphrase::RejectAll;

my $schema = TestSchema->connect('dbi:SQLite:dbname=:memory:');
$schema->deploy;

my $rs = $schema->resultset('Foo');

{
    my $id = $rs->create({
        passphrase_rfc2307 => 'moo',
        passphrase_crypt   => 'moo',
    })->id;

    my $row = $rs->find({ id => $id });

    like $row->get_column('passphrase_rfc2307'), qr/^\{SSHA\}/,
        'column stored as rfc2307 salted SHA digest';

    like $row->get_column('passphrase_crypt'), qr/^\$2a\$/,
        'column stored as unix blowfish crypt';

    for my $t (qw(rfc2307 crypt)) {
        my $ppr = $row->${\"passphrase_${t}"};
        isa_ok $ppr, 'Authen::Passphrase';

        ok !$ppr->match('mookooh'), 'rejects incorrect passphrase';
        ok $ppr->match('moo'), 'accepts correct passphrase';
    }
}

{
    my $id = $rs->create({
        passphrase_rfc2307 => Authen::Passphrase::RejectAll->new,
        passphrase_crypt   => Authen::Passphrase::RejectAll->new,
    })->id;

    my $row = $rs->find({ id => $id });

    is $row->get_column('passphrase_rfc2307'), '{CRYPT}*',
        'column stored as rfc2307';

    is $row->get_column('passphrase_crypt'), '*',
        'column stored as crypt';

    for my $t (qw(rfc2307 crypt)) {
        my $ppr = $row->${\"passphrase_${t}"};
        isa_ok $ppr, 'Authen::Passphrase::RejectAll';
    }
}

done_testing;
