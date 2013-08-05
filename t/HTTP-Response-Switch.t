use Test::Routine;
use Test::Routine::Util;
use Test::More;
use Test::Exception;

use HTTP::Response ();
use Module::Loaded 'is_loaded';
use Scalar::Util 'refaddr';

{
    package t::DispatcherException;
    use Moose;
    with 'Throwable';

    has 'response' => ( is => 'ro', required => 1 );
}

{
    package t::MyDispatcher1;
    use Moose;
    with 'HTTP::Response::Switch';

    sub handler_namespace { 't::lib::MyHandlers' }
    sub default_handlers { qw( Oops ) }
}

{
    package t::MyDispatcher2;
    use Moose;
    with 'HTTP::Response::Switch';

    sub handler_namespace { 't::lib::MyHandlers' }
    sub default_exception { 't::DispatcherException' }
}

test 'default_exception must act as documented' => sub {
    throws_ok
        { t::MyDispatcher1->default_exception }
        qr/\bunexpected HTTP response\b/;
};

test 'default_handlers must default to empty list' => sub {
    is_deeply(
        [ t::MyDispatcher2->default_handlers ],
        [],
    );
};

test 'load_handlers must cause handlers to load' => sub {
    for (qw{ Yes No Oops }) {
        ok(
            (not is_loaded("t::lib::MyHandlers::$_")),
            "handler $_ must not be loaded beforehand",
        );
    }
    lives_ok
        { t::MyDispatcher1->load_handlers }
        'call to load_handlers must succeed';
    for (qw{ Yes No Oops }) {
        ok(
            is_loaded("t::lib::MyHandlers::$_"),
            "handler $_ must be loaded afterwards",
        );
    }
};

my $r = HTTP::Response->new;

test 'default exception must be thrown as defined' => sub {
    throws_ok
        { t::MyDispatcher2->handle($r) }
        't::DispatcherException';
    my $e = $@;
    is refaddr $e->response, refaddr $r,
        'thrown exception must reference correct HTTP::Response';
};

test 'default exception must be thrown if all handlers decline' => sub {
    throws_ok
        { t::MyDispatcher2->handle($r, 'No') }
        't::DispatcherException';
};

test 'unexpected errors in handlers must propagate' => sub {
    throws_ok
        { t::MyDispatcher2->handle($r, 'No', 'Oops', 'Yes') }
        qr/\bsomething went wrong\b/;
};

test 'handle must succeed if a handler succeeds' => sub {
    lives_ok
        { t::MyDispatcher2->handle($r, 'No', 'Yes', 'Oops') };
};

test 'default handlers must be called upon' => sub {
    throws_ok
        { t::MyDispatcher1->handle($r, 'No') }
        qr/\bsomething went wrong\b/;
};

run_me;
done_testing;
