#!perl
#!perl -T

use Test::More;
eval "use Test::Pod::Coverage 1.04";
plan skip_all => "Test::Pod::Coverage 1.04 required for testing POD coverage" if $@;
all_pod_coverage_ok(
  {
    trustme => [
      qr/_for_(?:created|modified)_(?:on|after|before)\Z/,
      'as_html',
      'as_text',
    ]
  },
);
