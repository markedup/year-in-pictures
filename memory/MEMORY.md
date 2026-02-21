# Project Memory

## Environment
- Ruby is NOT on the bash/Git Bash PATH — it's a Windows-native install
- Run `bundle install` and `bundle exec rspec` from PowerShell or cmd, not bash

## Project
- Jekyll static site with Ruby backend for photo management
- Source code in `_lib/` (7 classes) and `_plugins/` (2 Jekyll plugins)
- SQLite database at `_db/yip.db`

## Tests
- RSpec added in Feb 2026 — first test suite for this project
- Specs live in `spec/lib/` (one file per `_lib/` class)
- Run with: `bundle exec rspec` or `bundle exec rake spec`
- Default rake task now runs `spec` then `build`
- SQL injection vulnerabilities in `Picture.get_all_by_month` and `Picture.get_all_by_photographer` are documented in `picture_spec.rb`
