#!/usr/bin/env perl6
use lib 'lib';
use Test;
use Log::Async;
use Jupyter::Kernel::Magics;

logger.add-tap( -> $msg { diag $msg<msg> } );

# plan 21;

my $m = Jupyter::Kernel::Magics.new;
class MockResult {
    has $.output;
    has $.output-mime-type;
    has $.stdout;
    has $.stdout-mime-type;
    has $.stderr;
    has $.exception;
    has $.incomplete;
}

{
    my $code = q:to/DONE/;
        no magic
        DONE
    ok !$m.find-magic($code), 'no magic';
}

{
    my $code = q:to/DONE/;
    %% javascript
    hello world
    DONE

    ok my $magic = $m.find-magic($code), 'preprocess recognized %% javascript';
    is $code, "hello world\n", 'find-magic removed magic line';
    my $r = $magic.preprocess($code);
    is $r.stdout-mime-type, 'application/javascript', 'js magic set the mime type';
}
{
    my $code = q:to/DONE/;
    %% latex
    "hello latex";
    DONE

    ok my $magic = $m.find-magic($code), 'find-magic recognized %% latex';
    is $code, qq["hello latex";\n], 'find-magic removed magic line';
    ok !$magic.preprocess($code), "preprocess did not return a result";
    is $code, qq["hello latex";\n], 'preprocess did not change code';
    my $result = $magic.postprocess(:result(MockResult.new));
    is $result.output-mime-type, 'text/latex', 'latex magic set the output mime type';
}
{
    my $code = q:to/DONE/;
    %% latex(equation*)
    "hello latex";
    DONE

    ok my $magic = $m.find-magic($code), 'find-magic recognized %% latex(equation*)';
    is $code, qq["hello latex";\n], 'find-magic removed magic line';
    ok !$magic.preprocess($code), "preprocess did not return a result";
    is $code, qq["hello latex";\n], 'preprocess did not change code';
    my $result = $magic.postprocess(:result(MockResult.new(:output<foo>)));
    is $result.output-mime-type, 'text/latex', 'latex magic set the output mime type';
    is $result.output, q:to/LATEX/, 'latex magic enclosed the output';
        \begin{equation*}
        foo
        \end{equation*}
        LATEX
}
{
    my $code = q:to/DONE/;
    %% html
    say "this is stdout";
    '<b>output</b>';
    DONE

    ok my $magic = $m.find-magic($code), 'find-magic recognized %% html';
    is $code, q:to/DONE/, 'find-magic removed magic line';
        say "this is stdout";
        '<b>output</b>';
        DONE
    ok !$magic.preprocess($code), "preprocess did not return a result";
    my $result = $magic.postprocess(:result(MockResult.new(
        :output('<b>output</b>'),
        :stdout("this is stdout\n"),
        )));
    is $result.output-mime-type, 'text/html', 'html magic set the output mime type';
    is $result.output, '<b>output</b>', 'html unchanged';
    is $result.stdout-mime-type, 'text/plain', 'stdout is text/plain';
    is $result.stdout, "this is stdout\n", 'stdout worked';
}
{
    my $code = q:to/DONE/;
    %% > html
    say '<b>this is stdout</b>';
    'output';
    DONE

    ok my $magic = $m.find-magic($code), 'find-magic recognized %% html';
    is $code, q:to/DONE/, 'find-magic removed magic line';
        say '<b>this is stdout</b>';
        'output';
        DONE
    ok !$magic.preprocess($code), "preprocess did not return a result";
    my $result = $magic.postprocess(:result(MockResult.new(
        :output('output'),
        :stdout("<b>this is stdout</b>\n"),
        )));
    is $result.output-mime-type, 'text/plain', 'html magic did not set output mime type';
    is $result.output, 'output', 'html unchanged';
    is $result.stdout-mime-type, 'text/html', 'stdout is text/html';
    is $result.stdout, "<b>this is stdout</b>\n", 'stdout worked';
}
{
    my $code = '#% html > html';
    ok my $magic = $m.find-magic($code), 'found magic for mime';
    is $magic.^name, 'Jupyter::Kernel::Magics::Magic::Filters', 'right magic';
    ok !$magic.preprocess($code), 'preprocess does not return true';
    my $result = MockResult.new(:output('going out'),:stdout('going to stdout'));
    ok $result = $magic.postprocess(:$result), 'postprocess returned a result';
    is $result.output-mime-type, 'text/html', 'set output mime type';
    is $result.stdout-mime-type, 'text/html', 'set stdout mime type';
}
{
    my $code = '#% html > latex';
    given $m.find-magic($code)
       .postprocess(:result( MockResult.new(:output<out>,:stdout<std>) )) {
       is .output-mime-type, 'text/html', 'generated html output';
       is .stdout-mime-type, 'text/latex', 'but latex on stdout';
    }
}
{
    my $code = '#% latex > html';
    given $m.find-magic($code)
       .postprocess(:result( MockResult.new(:output<out>,:stdout<std>) )) {
       is .output-mime-type, 'text/latex', 'generated latex output';
       is .stdout-mime-type, 'text/html', 'but html on stdout';
    }
}
{
    my $code = '#% latex(equation) > html';
    given $m.find-magic($code)
       .postprocess(:result( MockResult.new(:output<out>,:stdout<std>) )) {
       is .output-mime-type, 'text/latex', 'generated latex output';
       is .stdout-mime-type, 'text/html', 'but html on stdout';
    }
}
done-testing;

# vim: syn=perl6
