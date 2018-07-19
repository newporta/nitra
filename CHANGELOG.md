# Changelog
All notable changes to this project will be documented in this file.

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
