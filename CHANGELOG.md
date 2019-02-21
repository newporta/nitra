# Changelog
All notable changes to this project will be documented in this file.

## [1.0.10] - 2019-02-22
### Updated
- Remove deprecated has\_rdoc usage in nitra.gemspec

## [1.0.9] - 2019-01-09
### Updated
- Tighten up regex for replacing file locations in spec / cuke files. This should
  only be replaced in the extension.

## [1.0.8] - 2019-01-08
### Updated
- Made output file generate more robust to remove `[` and `]` from filenames when
  splitting rspec examples.

## [1.0.7] - 2018-12-19
### Added
- New option --split-rspec-files which supports splitting rspec tests. The existing --split-files
               has been renamed to --split-cucumber-files, with the former now deprecated.
- New option --split-rspec-files-regex which can be used in conjunction with --split-rspec-files.
               This will restrict which rspec files will be split. If not set, all rspec files will
               be split.

## [1.0.6] - 2018-11-30
### Added
- Ouput failures from tests which have failed and are retried. Currently a test which fails only outputs the filename so it is difficult to see what the actual root cause of the test error is.

## [1.0.5] - 2018-11-08
### Added
- Remove rails monkey patch initially added in `7a7e387`. This is causing breakage with tests using `fork` when using newer versions of mysql2. The connection sharing this monkey patch introduces causes connections to really be closed with newer versions of the gem. There seems to be no measurable performance difference without the monkey patch.

## [1.0.4] - 2018-11-07
### Added
- New option --retry-tags which allows retrying tests tagged with one of the configured tags.
- Initial support for Cucumber 3.x.

## [1.0.3] - 2018-07-19
### Added
- Add additional exit codes to differentiate nitras results. There only use to be two codes; '0' for success, '1' for failure. Now there are codes for: Aborted, Failure, Success, Test Failures, and Unprocessed Files

## [1.0.2] - 2018-04-10
### Added
- Support for cucumber formatter and options. (A concrete example is to configure the [cucumber junit formatter](https://relishapp.com/cucumber/cucumber/docs/formatters/junit-output-formatter) and consume and publish its output with the junit test results report option.)
- Support for rspec formatter and options. (A concrete example is to configure the [RspecJunitFormatter](https://github.com/sj26/rspec_junit_formatter) and consume and publish its output with the junit test results report option.)
- Added CHANGELOG

## [1.0.1] - 2016-10-31
### Added
- Add limited support for splitting Cucumber scenario outlines

## [1.0.0] - 2011-11-21
### Added
- Initial nitra implementation
