# Code Review Report: Year in Pictures

**Date:** 2026-02-15
**Reviewer:** Claude (Sonnet 4.5)
**Project:** Year in Pictures - Jekyll Photo Gallery
**Ruby Version:** 3.4.5

---

## Executive Summary

This Jekyll-based static site generator is generally well-structured with clear separation of concerns. However, several **critical security vulnerabilities** (SQL injection, command injection) and **resource management issues** (database connection leaks) require immediate attention. The codebase follows many Ruby conventions but lacks automated tests and comprehensive error handling.

### Overall Code Quality: **B-**

### Priority Breakdown
- **Critical Issues:** 2 (Security vulnerabilities)
- **High Priority:** 3 (Resource management)
- **Medium Priority:** 6 (Error handling, robustness)
- **Low Priority:** 6 (Code quality improvements)

---

## Table of Contents

1. [Critical Security Issues](#1-critical-security-issues)
2. [Resource Management Issues](#2-resource-management-issues)
3. [Code Quality & Ruby Idioms](#3-code-quality--ruby-idioms)
4. [Architecture & Design Patterns](#4-architecture--design-patterns)
5. [Testing & Maintainability](#5-testing--maintainability)
6. [Modern Ruby Improvements](#6-modern-ruby-improvements)
7. [Summary & Action Items](#7-summary--action-items)

---

## 1. Critical Security Issues

### 1.1 SQL Injection Vulnerabilities 🔴 CRITICAL

**Priority:** CRITICAL
**Severity:** HIGH
**Location:** `_lib/picture.rb:71-79`

#### Issue
String interpolation in SQL queries creates SQL injection vulnerabilities:

```ruby
def self.get_all_by_month(month, year)
  "SELECT filename, image_filename, caption, alt FROM pictures
   WHERE month='#{month}' and year=#{year} ORDER BY filename ASC;"
end

def self.get_all_by_photographer(photographer_id)
  "SELECT filename, image_filename, caption, alt, year FROM pictures
   WHERE photographer=#{photographer_id} ORDER BY year DESC, filename ASC;"
end
```

#### Justification
Even though these appear to be internal methods with controlled inputs, SQL injection is a critical security vulnerability. An attacker who can control the `month`, `year`, or `photographer_id` parameters could execute arbitrary SQL commands, potentially:
- Extracting sensitive data
- Modifying database contents
- Executing arbitrary SQL operations

#### Impact
- **Confidentiality:** HIGH - Database contents could be exposed
- **Integrity:** HIGH - Data could be modified or deleted
- **Availability:** MEDIUM - Database could be corrupted

#### Recommended Fix

**In `_lib/picture.rb`:**
```ruby
def self.get_all_by_month(month, year)
  "SELECT filename, image_filename, caption, alt FROM pictures
   WHERE month=? and year=? ORDER BY filename ASC;"
end

def self.get_all_by_photographer(photographer_id)
  "SELECT filename, image_filename, caption, alt, year FROM pictures
   WHERE photographer=? ORDER BY year DESC, filename ASC;"
end
```

**In `_lib/db_control.rb:91-98`:**
```ruby
def self.get_month_pictures(month, year)
  db = SQLite3::Database.open Config.database_path
  db.execute(Picture.get_all_by_month(month, year), [month, year])
end

def self.get_photographer_pictures(photographer_id)
  db = SQLite3::Database.open Config.database_path
  db.execute(Picture.get_all_by_photographer(photographer_id), [photographer_id])
end
```

#### Effort Estimate
- **Time:** 30 minutes
- **Complexity:** Low
- **Testing Required:** Verify all gallery pages render correctly

---

### 1.2 Command Injection Risk 🟡 HIGH

**Priority:** HIGH
**Severity:** MEDIUM
**Location:** `_lib/file_control.rb:55`

#### Issue
Direct system call with string interpolation:

```ruby
optimise_command = "jpegoptim -sq #{Config.thumbnails_directory(Config.last_month)}/*.jpg"
system(optimise_command)
```

#### Justification
If the path contains special shell characters (e.g., `;`, `|`, `$()`, backticks), this could lead to command injection. While `Config.last_month` is controlled internally, defensive programming requires safer alternatives. This is especially important if:
- Environment variables could be manipulated
- The codebase evolves to accept external input
- File paths come from less trusted sources

#### Impact
- **Confidentiality:** MEDIUM - Could execute arbitrary commands
- **Integrity:** HIGH - Could modify system files
- **Availability:** HIGH - Could damage system

#### Recommended Fix

Use array form of `system` which doesn't invoke a shell:

```ruby
def self.optimise_thumbnails
  thumbnail_path = "#{Config.thumbnails_directory(Config.last_month)}/*.jpg"
  system('jpegoptim', '-sq', thumbnail_path)
end
```

Or even better, with error handling:

```ruby
def self.optimise_thumbnails
  thumbnail_path = "#{Config.thumbnails_directory(Config.last_month)}/*.jpg"
  success = system('jpegoptim', '-sq', thumbnail_path)
  warn "Failed to optimize thumbnails" unless success
  success
end
```

#### Effort Estimate
- **Time:** 15 minutes
- **Complexity:** Low
- **Testing Required:** Run monthly task and verify thumbnails are optimized

---

## 2. Resource Management Issues

### 2.1 Database Connection Leaks 🟡 HIGH

**Priority:** HIGH
**Severity:** MEDIUM
**Location:** Multiple files

#### Issue
Database connections are opened but never explicitly closed:

```ruby
def self.add_years
  db = SQLite3::Database.open Config.database_path
  # ... operations ...
  # No db.close!
end
```

#### Affected Methods
- `_lib/db_control.rb:34` - `add_years`
- `_lib/db_control.rb:44` - `add_users`
- `_lib/db_control.rb:54` - `add_unknown_pic`
- `_lib/db_control.rb:63` - `add_pictures`
- `_lib/db_control.rb:92` - `get_month_pictures`
- `_lib/db_control.rb:97` - `get_photographer_pictures`
- `_lib/year.rb:35` - `first_year`
- `_lib/year.rb:42` - `last_year`

#### Justification
While Ruby's garbage collector will eventually close connections, explicit resource management is a best practice because:
- For long-running processes or frequent operations, this could exhaust database connections
- File descriptors are a limited resource on most systems
- Immediate cleanup is more predictable than GC-based cleanup
- SQLite locks the database file while connections are open

#### Impact
- **Performance:** MEDIUM - Could slow down under load
- **Reliability:** MEDIUM - Could cause connection exhaustion
- **Resource Usage:** HIGH - Wastes file descriptors

#### Recommended Fix

Use block form that auto-closes:

```ruby
def self.add_years
  SQLite3::Database.open(Config.database_path) do |db|
    years_data = YAML.load_file(Config.years_path)
    years_data.each do |year_data|
      year = Year.new(year_data)
      db.execute(year.insert_sql, year.values)
    end
  end
end

def self.get_month_pictures(month, year)
  SQLite3::Database.open(Config.database_path) do |db|
    db.execute(Picture.get_all_by_month(month, year), [month, year])
  end
end

def self.first_year
  SQLite3::Database.open(Config.database_path) do |db|
    db.get_first_value('select MIN(year) from years where year != 0;')
  end
end
```

#### Effort Estimate
- **Time:** 1 hour
- **Complexity:** Low-Medium (need to refactor 8 methods)
- **Testing Required:** Full integration test of build process

---

### 2.2 Unsafe YAML Loading 🟡 MEDIUM

**Priority:** MEDIUM
**Severity:** MEDIUM
**Location:** Multiple locations using `YAML.load_file`

#### Issue
`YAML.load_file` can deserialize arbitrary Ruby objects, posing a security risk:

```ruby
years_data = YAML.load_file(Config.years_path)
users_data = YAML.load_file(Config.users_path)['users']
pics_data = YAML.load_file(Config.source_file_from_year_path(year))['pictures']
pic_data = YAML.load_file(Config.unknown_pic_path).first
```

#### Justification
Modern Ruby recommends `YAML.safe_load` to prevent arbitrary code execution through YAML deserialization attacks. While this project controls its YAML sources, defense-in-depth is important because:
- YAML files are downloaded from an external Rails application
- A compromised Rails app could serve malicious YAML
- Future developers might not understand the security implications
- This is a well-documented attack vector (CVE-2013-0156, etc.)

#### Impact
- **Confidentiality:** HIGH - Could execute arbitrary code
- **Integrity:** HIGH - Could modify system
- **Availability:** HIGH - Could crash or damage system

#### Recommended Fix

```ruby
# In _lib/db_control.rb
years_data = YAML.safe_load_file(
  Config.years_path,
  permitted_classes: [Symbol],
  symbolize_names: true
)

users_data = YAML.safe_load_file(
  Config.users_path,
  permitted_classes: [Symbol],
  symbolize_names: true
)['users']

pics_data = YAML.safe_load_file(
  Config.source_file_from_year_path(year),
  permitted_classes: [Symbol],
  symbolize_names: true
)['pictures']
```

#### Effort Estimate
- **Time:** 30 minutes
- **Complexity:** Low
- **Testing Required:** Full build test to ensure YAML parsing works

---

### 2.3 Database Creation Logic Bug 🟡 MEDIUM

**Priority:** MEDIUM
**Severity:** MEDIUM
**Location:** `_lib/db_control.rb:9`

#### Issue
```ruby
def self.create
  db = SQLite3::Database.new Config.database_path unless File.exist? Config.database_path
  db.execute Picture.create_table_sql
  db.execute User.create_table_sql
  db.execute Year.create_table_sql
  # ...
end
```

#### Justification
This code has a logic error:
- If the file doesn't exist: `db` is created but never assigned (returns `nil` due to `unless`)
- If the file exists: `db` is `nil`
- Either way, `db.execute` will fail with NoMethodError

This suggests the method might not be used or tested properly.

#### Impact
- **Functionality:** HIGH - Method doesn't work as intended
- **Usability:** HIGH - Database creation will fail

#### Recommended Fix

```ruby
def self.create
  if File.exist? Config.database_path
    warn "Database already exists at #{Config.database_path}"
    return false
  end

  SQLite3::Database.open(Config.database_path) do |db|
    db.execute Picture.create_table_sql
    db.execute User.create_table_sql
    db.execute Year.create_table_sql
  end

  # Add setup data
  add_years
  add_users
  add_unknown_pic

  true
end
```

#### Effort Estimate
- **Time:** 20 minutes
- **Complexity:** Low
- **Testing Required:** Test `rake db_create` task

---

## 3. Code Quality & Ruby Idioms

### 3.1 Missing Error Handling 🟡 MEDIUM

**Priority:** MEDIUM
**Severity:** LOW
**Location:** `_lib/file_control.rb`

#### Issue
Network operations and file operations have no error handling:

```ruby
def self.download_latest_pictures_data
  year = Year.last_year
  yaml_content = URI.parse(Config.pictures_yaml_url(year)).open.read
  File.write(Config.source_file_from_year_path(year), yaml_content)
end
```

#### Justification
Network failures, permission issues, or disk space problems will cause ungraceful failures:
- No indication of what went wrong
- Stack traces are unfriendly to users
- Failed operations can't be retried intelligently
- Partial failures leave system in inconsistent state

#### Recommended Fix

```ruby
def self.download_latest_pictures_data
  year = Year.last_year

  begin
    puts "Downloading YAML for year #{year}..."
    yaml_content = URI.parse(Config.pictures_yaml_url(year)).open.read
    File.write(Config.source_file_from_year_path(year), yaml_content)
    puts "Successfully downloaded and saved YAML"
    true
  rescue OpenURI::HTTPError => e
    warn "Failed to download YAML for year #{year}: HTTP #{e.io.status[0]} - #{e.message}"
    false
  rescue Errno::EACCES, Errno::ENOSPC => e
    warn "Failed to write YAML file: #{e.message}"
    false
  rescue StandardError => e
    warn "Unexpected error: #{e.class} - #{e.message}"
    false
  end
end
```

Apply similar patterns to:
- `download_all_pictures_data`
- `download_user_data`
- `copy_main_pics`
- `copy_thumbnails`

#### Effort Estimate
- **Time:** 1 hour
- **Complexity:** Low
- **Testing Required:** Test failure scenarios

---

### 3.2 Redundant Conditional Check 🟢 LOW

**Priority:** LOW
**Severity:** LOW
**Location:** `_lib/asset_check.rb:59`

#### Issue
```ruby
def self.count_output(count_test)
  if count_test == true
    count_test.to_s.green
  else
    count_test.to_s.red
  end
end
```

#### Justification
Comparing boolean to `true` is redundant in Ruby. The idiomatic way is to test truthiness directly.

#### Recommended Fix

```ruby
def self.count_output(count_test)
  count_test ? count_test.to_s.green : count_test.to_s.red
end
```

#### Effort Estimate
- **Time:** 2 minutes
- **Complexity:** Trivial

---

### 3.3 Inefficient Array Access Pattern 🟢 LOW

**Priority:** LOW
**Severity:** LOW
**Location:** `_lib/year.rb:38,45`

#### Issue
```ruby
year.first.first  # Output is [[year]] hence this
```

#### Justification
While this works, it's unclear and requires a comment. SQLite3 provides cleaner methods for single values.

#### Recommended Fix

```ruby
def self.first_year
  SQLite3::Database.open(Config.database_path) do |db|
    db.get_first_value('select MIN(year) from years where year != 0;')
  end
end

def self.last_year
  SQLite3::Database.open(Config.database_path) do |db|
    db.get_first_value('select MAX(year) from years;')
  end
end
```

Or using `dig`:
```ruby
year.dig(0, 0)
```

#### Effort Estimate
- **Time:** 5 minutes
- **Complexity:** Trivial

---

### 3.4 Instance Variables Without Readers 🟢 LOW

**Priority:** LOW
**Severity:** LOW
**Location:** `_lib/picture.rb`, `_lib/user.rb`, `_lib/year.rb`

#### Issue
All instance variables are set in `initialize` but never exposed with `attr_reader`/`attr_accessor`.

#### Justification
While these classes work as data containers for database operations, having no accessors:
- Makes them less flexible for future use
- Prevents debugging and inspection
- Goes against Ruby conventions for data objects
- Will require changes if you ever need to read these values

#### Recommended Fix

```ruby
# _lib/picture.rb
class Picture
  attr_reader :image_filename, :title, :caption, :description, :alt,
              :month, :photographer, :year, :next, :prev, :filename

  def initialize(data, year, next_pic, prev_pic)
    @image_filename = data['image']
    @title = data['image_title']
    @caption = data['caption']
    @description = data['description']
    @alt = data['alt']
    @month = data['month']
    @photographer = data['photographer']
    @year = year
    @next = next_pic
    @prev = prev_pic
    @filename = generate_pagename
  end
  # ...
end

# _lib/user.rb
class User
  attr_reader :id, :name
  # ...
end

# _lib/year.rb
class Year
  attr_reader :year, :zodiac, :homepage
  # ...
end
```

#### Effort Estimate
- **Time:** 10 minutes
- **Complexity:** Trivial

---

### 3.5 Inconsistent String Concatenation 🟢 LOW

**Priority:** LOW
**Severity:** LOW
**Location:** `_plugins/picture.rb:26-38`

#### Issue
```ruby
def middle_html(pics, year)
  middle = ''
  pics.each do |pic|
    middle += <<-ITERATOR
      # ... HTML ...
    ITERATOR
  end
  middle
end
```

#### Justification
String concatenation with `+=` in a loop creates a new string object on each iteration, which is inefficient:
- O(n²) time complexity for string building
- Creates unnecessary garbage for GC
- Not idiomatic Ruby

#### Recommended Fix

```ruby
def middle_html(pics, year)
  pics.map do |pic|
    <<~HTML
      <li class="pure-u-1-2 pure-u-sm-1-2 pure-u-lg-1-3">
        <a title="#{pic[2]}" href="/photos/#{year}/#{pic[0]}">
          <img loading="lazy" alt="#{pic[3]}" src="/images/#{year}/thumbnails/#{pic[1]}">
        </a>
      </li>
    HTML
  end.join
end
```

Benefits:
- Uses `map` which is idiomatic Ruby
- Uses `<<~` (squiggly heredoc) to remove leading whitespace automatically
- More efficient (single join operation)

Similarly update `head_html` and `foot_html`:

```ruby
def head_html(year)
  <<~HTML
    <section class="month" id="#{@month}">
      <h2><a href="##{@month}">#{@month.capitalize} #{year}</a></h2>
      <ul class="polaroids pure-g">
  HTML
end

def foot_html
  <<~HTML
      </ul>
    </section>
  HTML
end
```

#### Effort Estimate
- **Time:** 15 minutes
- **Complexity:** Low

---

## 4. Architecture & Design Patterns

### 4.1 Missing Connection Pooling/Singleton Pattern 🟡 MEDIUM

**Priority:** MEDIUM
**Severity:** LOW
**Location:** Throughout `_lib/db_control.rb` and model classes

#### Issue
Every database query opens a new connection, even within the same operation.

#### Justification
For a static site generator that runs occasionally, this isn't critical. However:
- If this code is used in any long-running process, opening/closing connections repeatedly is inefficient
- Each connection has overhead (file open, SQLite header parsing, etc.)
- Multiple connections can cause locking issues with SQLite
- Makes future optimization (like connection pooling) harder

#### Recommended Fix

Option 1: Simple Singleton Pattern
```ruby
class DbControl
  class << self
    attr_reader :connection

    def connect
      @connection ||= SQLite3::Database.open(Config.database_path)
    end

    def disconnect
      @connection&.close
      @connection = nil
    end

    def with_connection
      connect
      yield @connection
    ensure
      # Don't close, keep connection alive
    end
  end

  def self.get_month_pictures(month, year)
    with_connection do |db|
      db.execute(Picture.get_all_by_month(month, year), [month, year])
    end
  end
end
```

Option 2: Connection Per Operation (Current + Cleanup)
Keep opening connections as needed but ensure proper cleanup with blocks (already covered in 2.1).

#### Effort Estimate
- **Time:** 2 hours (if implementing singleton)
- **Complexity:** Medium
- **Testing Required:** Full integration test

---

### 4.2 Magic Array Indices 🟡 MEDIUM

**Priority:** MEDIUM
**Severity:** MEDIUM
**Location:** `_plugins/picture.rb:31-32`, `_plugins/photographer_generator.rb:28`

#### Issue
```ruby
<a title="#{pic[2]}" href="/photos/#{year}/#{pic[0]}">
  <img loading="lazy" alt="#{pic[3]}" src="/images/#{year}/thumbnails/#{pic[1]}">
</a>
```

Also:
```ruby
pics_by_year = pics.group_by { |pic| pic[4] }  # "year" is the 5th element
```

#### Justification
Using array indices (pic[0], pic[1], etc.) is fragile and unclear:
- If the SQL query order changes, this breaks silently
- Requires comments to explain what each index means
- Makes code harder to maintain
- Error-prone when modifying queries

#### Recommended Fix

Use SQLite3's `results_as_hash` mode:

```ruby
# _lib/db_control.rb
def self.get_month_pictures(month, year)
  SQLite3::Database.open(Config.database_path) do |db|
    db.results_as_hash = true
    db.execute(Picture.get_all_by_month(month, year), [month, year])
  end
end

def self.get_photographer_pictures(photographer_id)
  SQLite3::Database.open(Config.database_path) do |db|
    db.results_as_hash = true
    db.execute(Picture.get_all_by_photographer(photographer_id), [photographer_id])
  end
end
```

Then update templates:

```ruby
# _plugins/picture.rb
def middle_html(pics, year)
  pics.map do |pic|
    <<~HTML
      <li class="pure-u-1-2 pure-u-sm-1-2 pure-u-lg-1-3">
        <a title="#{pic['caption']}" href="/photos/#{year}/#{pic['filename']}">
          <img loading="lazy" alt="#{pic['alt']}" src="/images/#{year}/thumbnails/#{pic['image_filename']}">
        </a>
      </li>
    HTML
  end.join
end
```

```ruby
# _plugins/photographer_generator.rb
pics_by_year = pics.group_by { |pic| pic['year'] }
```

#### Effort Estimate
- **Time:** 45 minutes
- **Complexity:** Medium
- **Testing Required:** Full visual test of all pages

---

### 4.3 No Database Transactions 🟢 LOW

**Priority:** LOW
**Severity:** LOW
**Location:** `_lib/db_control.rb:62-88` (`add_pictures`)

#### Issue
Bulk inserts don't use transactions, which is slower and less safe.

#### Justification
If the process crashes mid-way through adding pictures:
- You'll have a partially populated database
- No way to know where it stopped
- No atomicity guarantee
- Much slower (SQLite does implicit transaction per statement)

#### Recommended Fix

```ruby
def self.add_pictures(year_range)
  SQLite3::Database.open(Config.database_path) do |db|
    db.transaction do
      year_range.each do |year|
        pics_data = YAML.safe_load_file(
          Config.source_file_from_year_path(year),
          permitted_classes: [Symbol],
          symbolize_names: true
        )['pictures']

        pics_by_month = pics_data.group_by { |pic| pic['month'] }

        pics_data.each do |pic_data|
          month_pics = pics_by_month[pic_data['month']]
          current_index = month_pics.find_index(pic_data)

          next_index = (current_index + 1) % month_pics.length
          prev_index = (current_index - 1) % month_pics.length

          next_pic = Config.get_generated_pagename(month_pics[next_index]['image'])
          prev_pic = Config.get_generated_pagename(month_pics[prev_index]['image'])

          pic = Picture.new(pic_data, year, next_pic, prev_pic)
          db.execute(pic.insert_sql, pic.values)
        end
      end
    end
  end
end
```

Benefits:
- Much faster (one transaction vs. hundreds)
- All-or-nothing guarantee
- Can be rolled back on error

#### Effort Estimate
- **Time:** 20 minutes
- **Complexity:** Low

---

## 5. Testing & Maintainability

### 5.1 No Tests 🟡 MEDIUM

**Priority:** MEDIUM
**Severity:** MEDIUM
**Location:** Project-wide

#### Issue
The codebase has no test suite (no `spec/` or `test/` directory).

#### Justification
While this is a small project, having tests would:
- Prevent regressions when making improvements
- Document expected behavior
- Make refactoring safer (especially for the fixes in this report)
- Catch the SQL injection vulnerabilities automatically
- Enable confident deployment
- Help new developers understand the code

#### Recommended Approach

Add minitest (built into Ruby):

```ruby
# Gemfile
group :test do
  gem 'minitest'
  gem 'minitest-reporters'  # For prettier output
end
```

Create test structure:
```
test/
├── test_helper.rb
├── lib/
│   ├── config_test.rb
│   ├── db_control_test.rb
│   ├── picture_test.rb
│   ├── user_test.rb
│   └── year_test.rb
└── plugins/
    ├── picture_test.rb
    └── photographer_generator_test.rb
```

Example test:

```ruby
# test/lib/picture_test.rb
require_relative '../test_helper'
require_relative '../../_lib/picture'

class PictureTest < Minitest::Test
  def setup
    @pic_data = {
      'image' => '01-example.jpg',
      'image_title' => 'Example',
      'caption' => 'An example picture',
      'description' => 'Description here',
      'alt' => 'Alt text',
      'month' => 'january',
      'photographer' => 1
    }
    @picture = Picture.new(@pic_data, 2026, 'next.html', 'prev.html')
  end

  def test_generate_pagename
    assert_equal '01-example.html', @picture.generate_pagename
  end

  def test_sql_injection_prevention
    # This test would fail with current code, pass after fix
    sql = Picture.get_all_by_month("'; DROP TABLE pictures; --", 2026)
    refute_includes sql, 'DROP TABLE', 'SQL should use parameters, not interpolation'
  end
end
```

Add Rake task:

```ruby
# Rakefile
desc 'Run tests'
task :test do
  require 'rake/testtask'
  Rake::TestTask.new do |t|
    t.libs << 'test'
    t.test_files = FileList['test/**/*_test.rb']
    t.verbose = true
  end
end
```

#### Effort Estimate
- **Time:** 4-8 hours (initial setup + basic tests)
- **Complexity:** Medium
- **Ongoing:** 15-30 min per feature

---

### 5.2 Hardcoded Date Logic 🟢 LOW

**Priority:** LOW
**Severity:** LOW
**Location:** `_lib/file_control.rb:9`

#### Issue
```ruby
next if (2015..2018).include? year
```

The comment says "Skip the early years - this predates the Rails application so no data there" but this is hardcoded.

#### Justification
This hardcoded range:
- Will need updating as requirements change
- Reason isn't immediately clear from code alone
- Should be in configuration
- Makes assumptions about data availability

#### Recommended Fix

Move to configuration:

```ruby
# _lib/config.rb
class Config
  def self.rails_app_start_year
    ENV.fetch('YIP_RAILS_APP_START_YEAR', '2019').to_i
  end

  def self.manual_data_years
    2015...(rails_app_start_year)
  end
end

# _lib/file_control.rb
def self.download_all_pictures_data
  Config.year_range.each do |year|
    # Skip years that predate the Rails application
    next if year < Config.rails_app_start_year

    yaml_content = URI.parse(Config.pictures_yaml_url(year)).open.read
    File.write(Config.source_file_from_year_path(year), yaml_content)
  end
end
```

#### Effort Estimate
- **Time:** 15 minutes
- **Complexity:** Low

---

## 6. Modern Ruby Improvements

### 6.1 Use Frozen String Literals 🟢 LOW

**Priority:** LOW
**Severity:** LOW
**Location:** `.rubocop.yml` and all Ruby files

#### Issue
`.rubocop.yml` disables frozen string literal comments:
```yaml
Style/FrozenStringLiteralComment:
  Enabled: false
```

#### Justification
Frozen string literals (Ruby 2.3+):
- Improve performance by preventing unnecessary string object creation
- Prevent accidental string mutations
- Are Ruby 3+ default behavior
- Are modern Ruby best practice
- Reduce memory usage

#### Recommended Fix

1. Enable in RuboCop:
```yaml
# .rubocop.yml
Style/FrozenStringLiteralComment:
  Enabled: true
  EnforcedStyle: always
```

2. Add to top of each Ruby file:
```ruby
# frozen_string_literal: true
```

3. Or use RuboCop auto-correct:
```bash
rubocop --auto-correct-all
```

4. Fix any strings that need to be mutable:
```ruby
name = +"mutable string"  # The + makes it mutable
```

#### Effort Estimate
- **Time:** 30 minutes (mostly automated)
- **Complexity:** Low
- **Testing Required:** Full test suite run

---

### 6.2 Consider Using Struct for Simple Models 🟢 LOW

**Priority:** LOW
**Severity:** LOW
**Location:** `_lib/user.rb`, possibly `_lib/year.rb`

#### Issue
Simple data classes like `User` are implemented as full classes.

#### Justification
For simple data containers, Ruby's `Struct` or `Data` (Ruby 3.2+) provides:
- Automatic `attr_reader` generation
- Equality comparison
- Less boilerplate
- Clear intent that it's a data object

#### Recommended Fix

```ruby
# _lib/user.rb
# frozen_string_literal: true

require 'sqlite3'
require_relative 'config'

# Using Ruby 3.2+ Data class (immutable by default)
User = Data.define(:id, :name) do
  def self.from_hash(user_data)
    new(id: user_data['id'], name: user_data['name'])
  end

  def insert_sql
    'INSERT OR REPLACE INTO users (id, name) VALUES (?, ?)'
  end

  def values
    [id, name]
  end

  def self.create_table_sql
    <<~SQL
      create table users (
        id INT UNIQUE PRIMARY KEY,
        name TEXT
      );
    SQL
  end
end
```

Or for Ruby 3.0+ using Struct:
```ruby
class User < Struct.new(:id, :name, keyword_init: true)
  # ... methods ...
end
```

Benefits:
- Less boilerplate
- Automatic accessors
- Built-in equality
- Hash conversion
- Clear data object semantics

#### Effort Estimate
- **Time:** 30 minutes
- **Complexity:** Low
- **Testing Required:** Verify database operations work

---

### 6.3 Modern Hash Syntax 🟢 LOW

**Priority:** LOW
**Severity:** LOW
**Location:** Throughout codebase

#### Issue
Code uses YAML with string keys but could benefit from symbol keys:

```ruby
@image_filename = data['image']
@title = data['image_title']
```

#### Justification
Modern Ruby prefers symbol keys for hashes when keys are known at coding time:
- Slightly better performance
- More idiomatic
- Less prone to typos (symbols have better error messages)
- Clearer intent

#### Recommended Fix

When loading YAML, use `symbolize_names`:

```ruby
pics_data = YAML.safe_load_file(
  Config.source_file_from_year_path(year),
  permitted_classes: [Symbol],
  symbolize_names: true
)['pictures']
```

Then access with symbols:
```ruby
@image_filename = data[:image]
@title = data[:image_title]
```

#### Effort Estimate
- **Time:** 45 minutes
- **Complexity:** Low-Medium
- **Testing Required:** Full integration test

---

## 7. Summary & Action Items

### Priority Matrix

| Priority | Issue | Impact | Effort | ROI |
|----------|-------|--------|--------|-----|
| 🔴 CRITICAL | SQL Injection | High | Low | ⭐⭐⭐⭐⭐ |
| 🔴 HIGH | Command Injection | Medium | Low | ⭐⭐⭐⭐⭐ |
| 🔴 HIGH | DB Connection Leaks | Medium | Medium | ⭐⭐⭐⭐ |
| 🟡 MEDIUM | Unsafe YAML Loading | Medium | Low | ⭐⭐⭐⭐ |
| 🟡 MEDIUM | DB Creation Bug | High | Low | ⭐⭐⭐⭐ |
| 🟡 MEDIUM | Missing Error Handling | Low | Medium | ⭐⭐⭐ |
| 🟡 MEDIUM | Magic Array Indices | Medium | Medium | ⭐⭐⭐ |
| 🟡 MEDIUM | No Tests | Medium | High | ⭐⭐⭐ |
| 🟡 MEDIUM | Connection Pooling | Low | High | ⭐⭐ |
| 🟢 LOW | Code Quality Issues | Low | Low | ⭐⭐ |

### Immediate Action Items (Week 1)

1. **Fix SQL injection vulnerabilities** (30 min)
   - Update `Picture.get_all_by_month` and `Picture.get_all_by_photographer`
   - Update callers in `DbControl`
   - Test all gallery pages

2. **Fix command injection risk** (15 min)
   - Update `FileControl.optimise_thumbnails`
   - Test monthly task

3. **Fix database creation bug** (20 min)
   - Fix `DbControl.create` logic
   - Test `rake db_create`

4. **Close database connections** (1 hour)
   - Refactor all DB methods to use blocks
   - Test full build process

### Short-term Actions (Month 1)

5. **Use safe YAML loading** (30 min)
6. **Add error handling to file operations** (1 hour)
7. **Fix magic array indices** (45 min)
8. **Add basic test suite** (4-8 hours)

### Long-term Improvements (Month 2+)

9. **Enable frozen string literals** (30 min)
10. **Add database transactions** (20 min)
11. **Refactor to use hash-based DB results** (1 hour)
12. **Consider connection pooling** (2 hours)
13. **Add comprehensive tests** (ongoing)

### Estimated Total Effort

- **Critical fixes:** 2-3 hours
- **High priority:** 4-5 hours
- **Medium priority:** 8-10 hours
- **Low priority:** 2-3 hours
- **Testing infrastructure:** 4-8 hours

**Total: 20-30 hours** for complete remediation

### Risk Assessment

**Current Risk Level: MEDIUM-HIGH**

- **Security:** HIGH (SQL injection, command injection)
- **Reliability:** MEDIUM (resource leaks, no error handling)
- **Maintainability:** MEDIUM (no tests, magic values)
- **Performance:** LOW (acceptable for static site generator)

**After Critical Fixes: LOW**

- **Security:** LOW
- **Reliability:** MEDIUM
- **Maintainability:** MEDIUM-HIGH (with tests)
- **Performance:** LOW

### Recommendations

1. **Immediately** address security vulnerabilities (SQL injection, command injection)
2. **This week** fix resource management (DB connections, creation bug)
3. **This month** add error handling and basic tests
4. **Ongoing** improve code quality and add comprehensive tests

### Positive Aspects

The codebase has several strengths:
- Clear separation of concerns (models, controllers, plugins)
- Consistent naming conventions
- RuboCop configuration for code quality
- Sensible project structure
- Good use of Jekyll patterns
- Clear database schema design
- Useful Rake tasks for automation

---

## Appendix A: File-by-File Summary

### `_lib/config.rb`
- **Grade:** B+
- **Issues:** None major
- **Recommendations:** Consider moving hardcoded years to environment variables

### `_lib/db_control.rb`
- **Grade:** C
- **Issues:** Connection leaks, creation bug, no transactions, SQL injection
- **Recommendations:** Fix all issues listed in sections 1.1, 2.1, 2.3, 4.3

### `_lib/picture.rb`
- **Grade:** C-
- **Issues:** SQL injection (critical), no accessors
- **Recommendations:** Fix SQL injection immediately, add attr_readers

### `_lib/user.rb`
- **Grade:** B
- **Issues:** No accessors
- **Recommendations:** Consider using Struct/Data class

### `_lib/year.rb`
- **Grade:** B-
- **Issues:** Connection leaks, awkward array access
- **Recommendations:** Use `get_first_value`, fix connections

### `_lib/asset_check.rb`
- **Grade:** B+
- **Issues:** Minor redundant conditional
- **Recommendations:** Simplify `count_output` method

### `_lib/file_control.rb`
- **Grade:** C
- **Issues:** Command injection, no error handling, hardcoded dates
- **Recommendations:** Fix security issue, add comprehensive error handling

### `_plugins/picture.rb`
- **Grade:** B-
- **Issues:** Inefficient string concatenation, magic indices
- **Recommendations:** Use map/join, use hash-based results

### `_plugins/photographer_generator.rb`
- **Grade:** B
- **Issues:** Magic array indices
- **Recommendations:** Use hash-based results

### `Rakefile`
- **Grade:** A-
- **Issues:** None major
- **Recommendations:** Add test task

---

## Appendix B: References

- [Ruby Security Guide](https://guides.rubyonrails.org/security.html)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Ruby Style Guide](https://rubystyle.guide/)
- [SQLite3 Ruby Documentation](https://github.com/sparklemotion/sqlite3-ruby)
- [Ruby Best Practices](https://www.rubypigeon.com/posts/ruby-best-practices/)
- [Bundler Best Practices](https://bundler.io/guides/best_practices.html)

---

## Document Metadata

- **Generated:** 2026-02-15
- **Tool:** Claude Code (Sonnet 4.5)
- **Version:** 1.0
- **Format:** Markdown
- **License:** Internal Use

---

**End of Report**