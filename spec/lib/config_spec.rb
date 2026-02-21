require_relative '../../_lib/config'

RSpec.describe Config do
  describe '.database_path' do
    it 'returns the path to the SQLite database' do
      expect(Config.database_path).to eq('_db/yip.db')
    end
  end

  describe '.years_path' do
    it 'returns the years YAML config path' do
      expect(Config.years_path).to eq('_config/years.yml')
    end
  end

  describe '.unknown_pic_path' do
    it 'returns the unknown picture YAML path' do
      expect(Config.unknown_pic_path).to eq('_config/unknown_pic.yml')
    end
  end

  describe '.source_file_from_year_path' do
    it 'returns the correct data file path for a given year' do
      expect(Config.source_file_from_year_path(2023)).to eq('_db/data/2023.yml')
    end
  end

  describe '.get_generated_pagename' do
    it 'strips the directory and extension and appends .html' do
      expect(Config.get_generated_pagename('path/to/photo.jpg')).to eq('photo.html')
    end

    it 'handles filenames with no directory path' do
      expect(Config.get_generated_pagename('photo.jpg')).to eq('photo.html')
    end

    it 'handles filenames with multiple dots in the name' do
      expect(Config.get_generated_pagename('my.photo.2024.jpg')).to eq('my.photo.2024.html')
    end
  end

  describe '.image_directory' do
    it 'returns the images directory for the given year' do
      expect(Config.image_directory({ year: 2025, month: 3 })).to eq('images/2025')
    end
  end

  describe '.thumbnails_directory' do
    it 'returns the thumbnails subdirectory under image_directory' do
      expect(Config.thumbnails_directory({ year: 2025, month: 3 })).to eq('images/2025/thumbnails')
    end
  end

  describe '.last_month' do
    context 'when the current month is not January' do
      before { allow(Time).to receive(:now).and_return(Time.new(2025, 6, 15)) }

      it 'returns the previous month number' do
        expect(Config.last_month[:month]).to eq(5)
      end

      it 'returns the same year' do
        expect(Config.last_month[:year]).to eq(2025)
      end
    end

    context 'when the current month is January (year boundary)' do
      before { allow(Time).to receive(:now).and_return(Time.new(2026, 1, 10)) }

      it 'returns December (month 12)' do
        expect(Config.last_month[:month]).to eq(12)
      end

      it 'returns the previous year' do
        expect(Config.last_month[:year]).to eq(2025)
      end
    end

    context 'when the current month is February' do
      before { allow(Time).to receive(:now).and_return(Time.new(2024, 2, 1)) }

      it 'returns January (month 1)' do
        expect(Config.last_month[:month]).to eq(1)
      end

      it 'returns the same year' do
        expect(Config.last_month[:year]).to eq(2024)
      end
    end
  end
end
