#!perl -T

use Test::More;
eval "use Test::Pod::Coverage 1.07";
plan skip_all => "Test::Pod::Coverage 1.07 required for testing POD coverage"
  if $@;
all_pod_coverage_ok(
  {
    coverage_class => 'Pod::Coverage::CountParents',
    trustme => [
      qr/_for_(?:created|modified)_(?:on|after|before)\Z/,
      'describe_options',
      'as_html',
      'as_text',
    ]
  },
);
