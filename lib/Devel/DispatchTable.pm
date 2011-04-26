package Devel::DispatchTable;
use strict;
use warnings;
use Devel::EvalContext;
use Carp ();
use Readonly;
use base qw(Class::Accessor);
__PACKAGE__->mk_accessors($_) for qw(_cxt _table);

our $DESTROY_HANDLER_NAME => '__DESTROY__';

sub new {
    my ($class, $args) = @_;
    Carp::croak("no arguments") unless defined $args;

    my $handlers = delete $args->{handlers};
    Carp::croak("no handlers specified in call to $class constructor")
        unless defined $handlers;
    Carp::croak("handlers must be a HASH reference") 
        unless ref $handlers eq 'HASH';

    my $context = delete $args->{context};
    Carp::croak("no context specified in call to $class constructor")
        unless defined $context;
    Carp::croak("context must be a SCALAR") 
        if ref $context;
    
    my $self = $class->SUPER::new;
    $self->_setup_context($context);
    $self->_configure_with_handlers($handlers);
    $self;
}

sub _setup_context {
    my ($self, $context) = @_;
    return unless defined $context;
    my $cxt = Devel::EvalContext->new;
    $cxt->run($context);
    $self->_cxt($cxt);
}

sub _configure_with_handlers {
    my ($self, $handlers) = @_;
    my $table = {};
    while (my ($handler, $code) = each %$handlers) { 
        if (ref $code) {
            Carp::croak("error processing handler '$handler': code must be a SCALAR", 
            "not a ", ref $code);
        }
        $table->{$handler} = $code;
    }
    $self->_table($table);
}

sub _handler_exists {
    my ($self, $h_name) = @_;
    return exists $self->_table->{$h_name};
}

sub dispatch {
    my ($self, $h) = @_;
    Carp::croak("no such handler: $h") unless $self->_handler_exists($h);
    $self->_cxt->run( $self->_handler_for( $h ) );
}

sub DESTROY {
    my $self = shift;
    if ($self->_handler_exists($DESTROY_HANDLER_NAME)) {
        $self->dispatch($DESTROY_HANDLER_NAME);
    }
}

1;
