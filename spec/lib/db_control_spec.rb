require 'sqlite3'
require 'tmpdir'
require 'yaml'
require_relative '../../_lib/config'
require_relative '../../_lib/picture'
require_relative '../../_lib/user'
require_relative '../../_lib/year'
require_relative '../../_lib/db_control'

RSpec.describe DbControl do
  describe '.add_pictures' do
    let(:db_path) { File.join(Dir.tmpdir, "yip_dbctrl_test_#{Process.pid}.db") }

    before do
      db = SQLite3::Database.new(db_path)
      db.execute(Year.create_table_sql)
      db.execute(User.create_table_sql)
      db.execute(Picture.create_table_sql)
      db.close
      allow(Config).to receive(:database_path).and_return(db_path)
    end

    after { File.delete(db_path) if File.exist?(db_path) }

    # Query helper: fetches prev and next for a picture by filename, month, year
    def row_for(db_path, filename, month, year)
      db = SQLite3::Database.new(db_path)
      db.results_as_hash = true
      row = db.execute(
        'SELECT filename, prev, next FROM pictures WHERE filename = ? AND month = ? AND year = ?',
        [filename, month, year]
      ).first
      db.close
      row
    end

    context 'with three pictures in the same month' do
      let(:pics_yaml) do
        {
          'pictures' => [
            { 'image' => '01-alpha.jpg',   'image_title' => 'Alpha',   'caption' => '', 'description' => '', 'alt' => '', 'month' => 'january', 'photographer' => 1 },
            { 'image' => '01-bravo.jpg',   'image_title' => 'Bravo',   'caption' => '', 'description' => '', 'alt' => '', 'month' => 'january', 'photographer' => 1 },
            { 'image' => '01-charlie.jpg', 'image_title' => 'Charlie', 'caption' => '', 'description' => '', 'alt' => '', 'month' => 'january', 'photographer' => 1 }
          ]
        }
      end

      before do
        allow(YAML).to receive(:load_file).and_return(pics_yaml)
        DbControl.add_pictures(2025..2025)
      end

      it 'sets the next for the first picture to the second' do
        expect(row_for(db_path, '01-alpha.html', 'january', 2025)['next']).to eq('01-bravo.html')
      end

      it 'wraps prev for the first picture around to the last' do
        expect(row_for(db_path, '01-alpha.html', 'january', 2025)['prev']).to eq('01-charlie.html')
      end

      it 'sets next and prev correctly for the middle picture' do
        row = row_for(db_path, '01-bravo.html', 'january', 2025)
        expect(row['next']).to eq('01-charlie.html')
        expect(row['prev']).to eq('01-alpha.html')
      end

      it 'wraps next for the last picture around to the first' do
        expect(row_for(db_path, '01-charlie.html', 'january', 2025)['next']).to eq('01-alpha.html')
      end

      it 'sets prev for the last picture to the middle' do
        expect(row_for(db_path, '01-charlie.html', 'january', 2025)['prev']).to eq('01-bravo.html')
      end
    end

    context 'with a single picture in a month' do
      let(:pics_yaml) do
        {
          'pictures' => [
            { 'image' => '01-solo.jpg', 'image_title' => 'Solo', 'caption' => '', 'description' => '', 'alt' => '', 'month' => 'january', 'photographer' => 1 }
          ]
        }
      end

      before do
        allow(YAML).to receive(:load_file).and_return(pics_yaml)
        DbControl.add_pictures(2025..2025)
      end

      it 'sets next to itself' do
        expect(row_for(db_path, '01-solo.html', 'january', 2025)['next']).to eq('01-solo.html')
      end

      it 'sets prev to itself' do
        expect(row_for(db_path, '01-solo.html', 'january', 2025)['prev']).to eq('01-solo.html')
      end
    end

    context 'with pictures across multiple months' do
      let(:pics_yaml) do
        {
          'pictures' => [
            { 'image' => '01-jan-a.jpg', 'image_title' => 'Jan A', 'caption' => '', 'description' => '', 'alt' => '', 'month' => 'january',  'photographer' => 1 },
            { 'image' => '01-jan-b.jpg', 'image_title' => 'Jan B', 'caption' => '', 'description' => '', 'alt' => '', 'month' => 'january',  'photographer' => 1 },
            { 'image' => '02-feb-a.jpg', 'image_title' => 'Feb A', 'caption' => '', 'description' => '', 'alt' => '', 'month' => 'february', 'photographer' => 1 }
          ]
        }
      end

      before do
        allow(YAML).to receive(:load_file).and_return(pics_yaml)
        DbControl.add_pictures(2025..2025)
      end

      it 'keeps navigation within each month — does not link across months' do
        jan_a = row_for(db_path, '01-jan-a.html', 'january',  2025)
        jan_b = row_for(db_path, '01-jan-b.html', 'january',  2025)
        feb_a = row_for(db_path, '02-feb-a.html', 'february', 2025)

        # January pictures link to each other
        expect(jan_a['next']).to eq('01-jan-b.html')
        expect(jan_b['prev']).to eq('01-jan-a.html')

        # February's only picture is self-referential
        expect(feb_a['next']).to eq('02-feb-a.html')
        expect(feb_a['prev']).to eq('02-feb-a.html')
      end
    end

    context 'when processing multiple years' do
      let(:year_2024_yaml) do
        {
          'pictures' => [
            { 'image' => '03-march.jpg', 'image_title' => 'March', 'caption' => '', 'description' => '', 'alt' => '', 'month' => 'march', 'photographer' => 1 }
          ]
        }
      end

      let(:year_2025_yaml) do
        {
          'pictures' => [
            { 'image' => '04-april.jpg', 'image_title' => 'April', 'caption' => '', 'description' => '', 'alt' => '', 'month' => 'april', 'photographer' => 1 }
          ]
        }
      end

      before do
        allow(YAML).to receive(:load_file)
          .with(Config.source_file_from_year_path(2024))
          .and_return(year_2024_yaml)
        allow(YAML).to receive(:load_file)
          .with(Config.source_file_from_year_path(2025))
          .and_return(year_2025_yaml)
        DbControl.add_pictures(2024..2025)
      end

      it 'inserts pictures from each year' do
        expect(row_for(db_path, '03-march.html', 'march', 2024)).not_to be_nil
        expect(row_for(db_path, '04-april.html', 'april', 2025)).not_to be_nil
      end

      it 'records the correct year for each picture' do
        march = row_for(db_path, '03-march.html', 'march', 2024)
        april = row_for(db_path, '04-april.html', 'april', 2025)
        expect(march).not_to be_nil
        expect(april).not_to be_nil
      end
    end
  end
end
