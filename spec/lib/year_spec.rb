require 'sqlite3'
require 'tmpdir'
require_relative '../../_lib/config'
require_relative '../../_lib/year'

RSpec.describe Year do
  let(:year_data) { { 'year' => 2024, 'zodiac' => 'Dragon', 'homepage' => 'https://example.com/2024' } }

  subject(:year) { Year.new(year_data) }

  describe '#initialize' do
    it 'sets the year' do
      expect(year.instance_variable_get(:@year)).to eq(2024)
    end

    it 'sets the zodiac sign' do
      expect(year.instance_variable_get(:@zodiac)).to eq('Dragon')
    end

    it 'sets the homepage URL' do
      expect(year.instance_variable_get(:@homepage)).to eq('https://example.com/2024')
    end
  end

  describe '#insert_sql' do
    it 'uses parameterized placeholders' do
      expect(year.insert_sql).to include('VALUES (?, ?, ?)')
    end

    it 'targets the years table with INSERT OR REPLACE' do
      expect(year.insert_sql).to include('INSERT OR REPLACE INTO years')
    end
  end

  describe '#values' do
    it 'returns [year, zodiac, homepage]' do
      expect(year.values).to eq([2024, 'Dragon', 'https://example.com/2024'])
    end
  end

  describe '.create_table_sql' do
    it 'creates a years table' do
      expect(Year.create_table_sql).to include('create table years')
    end

    it 'defines year as a unique primary key' do
      expect(Year.create_table_sql).to include('year INT UNIQUE PRIMARY KEY')
    end
  end

  describe '.first_year and .last_year' do
    let(:db_path) { File.join(Dir.tmpdir, "yip_year_test_#{Process.pid}.db") }

    before do
      db = SQLite3::Database.new(db_path)
      db.execute(Year.create_table_sql)
      [
        { 'year' => 0,    'zodiac' => 'Unknown', 'homepage' => '' },
        { 'year' => 2019, 'zodiac' => 'Pig',     'homepage' => '' },
        { 'year' => 2023, 'zodiac' => 'Rabbit',  'homepage' => '' },
        { 'year' => 2025, 'zodiac' => 'Snake',   'homepage' => '' }
      ].each do |data|
        y = Year.new(data)
        db.execute(y.insert_sql, y.values)
      end
      db.close
      allow(Config).to receive(:database_path).and_return(db_path)
    end

    after { File.delete(db_path) if File.exist?(db_path) }

    describe '.first_year' do
      it 'returns the smallest non-zero year' do
        expect(Year.first_year).to eq(2019)
      end

      it 'excludes the placeholder year 0' do
        expect(Year.first_year).not_to eq(0)
      end
    end

    describe '.last_year' do
      it 'returns the largest year in the database' do
        expect(Year.last_year).to eq(2025)
      end
    end
  end
end
