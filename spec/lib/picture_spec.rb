require_relative '../../_lib/picture'

RSpec.describe Picture do
  let(:data) do
    {
      'image'        => 'photos/summer/beach.jpg',
      'image_title'  => 'Beach Sunset',
      'caption'      => 'A golden sunset over the beach',
      'description'  => 'Long description here',
      'alt'          => 'Sunset over a calm beach',
      'month'        => 'july',
      'photographer' => 3
    }
  end

  subject(:picture) { Picture.new(data, 2024, 'pier.html', 'cliff.html') }

  describe '#initialize' do
    it 'sets the year' do
      expect(picture.instance_variable_get(:@year)).to eq(2024)
    end

    it 'sets the next page' do
      expect(picture.instance_variable_get(:@next)).to eq('pier.html')
    end

    it 'sets the prev page' do
      expect(picture.instance_variable_get(:@prev)).to eq('cliff.html')
    end

    it 'derives the page filename from the image filename' do
      expect(picture.instance_variable_get(:@filename)).to eq('beach.html')
    end
  end

  describe '#generate_pagename' do
    it 'strips the directory and extension and appends .html' do
      expect(picture.generate_pagename).to eq('beach.html')
    end

    it 'handles filenames with no directory' do
      flat_data = data.merge('image' => 'photo.jpg')
      pic = Picture.new(flat_data, 2024, '', '')
      expect(pic.generate_pagename).to eq('photo.html')
    end
  end

  describe '#insert_sql' do
    it 'uses parameterized placeholders — not string interpolation' do
      expect(picture.insert_sql).to include('VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)')
    end

    it 'does not embed any literal values in the SQL' do
      expect(picture.insert_sql).not_to include('beach')
      expect(picture.insert_sql).not_to include('2024')
    end
  end

  describe '#values' do
    it 'returns an array of 12 elements' do
      expect(picture.values.length).to eq(12)
    end

    it 'puts the derived html filename first' do
      expect(picture.values[0]).to eq('beach.html')
    end

    it 'puts the original image path second' do
      expect(picture.values[1]).to eq('photos/summer/beach.jpg')
    end

    it 'puts prev at index 9 and next at index 10' do
      values = picture.values
      expect(values[9]).to eq('cliff.html')
      expect(values[10]).to eq('pier.html')
    end

    it 'builds a unique_name from filename + month + year' do
      expect(picture.values[11]).to eq('beach.htmljuly2024')
    end
  end

  describe '.create_table_sql' do
    it 'creates a pictures table' do
      expect(Picture.create_table_sql).to include('create table pictures')
    end

    it 'includes a UNIQUE constraint on unique_name' do
      expect(Picture.create_table_sql).to include('unique_name TEXT UNIQUE')
    end

    it 'declares a foreign key on year' do
      expect(Picture.create_table_sql).to include('FOREIGN KEY (year) REFERENCES years')
    end

    it 'declares a foreign key on photographer' do
      expect(Picture.create_table_sql).to include('FOREIGN KEY (photographer) REFERENCES users')
    end
  end

  describe '.get_all_by_month' do
    it 'embeds the month and year directly in the SQL string' do
      sql = Picture.get_all_by_month('july', 2024)
      expect(sql).to include("'july'")
      expect(sql).to include('2024')
    end

    it 'orders results by filename ascending' do
      sql = Picture.get_all_by_month('july', 2024)
      expect(sql).to match(/ORDER BY filename ASC/i)
    end

    it 'is vulnerable to SQL injection via the month parameter' do
      # This test documents the vulnerability: the injected string appears
      # verbatim in the query rather than being safely parameterized.
      injected = "' OR '1'='1"
      sql = Picture.get_all_by_month(injected, 2024)
      expect(sql).to include(injected)
    end
  end

  describe '.get_all_by_photographer' do
    it 'embeds the photographer_id directly in the SQL string' do
      sql = Picture.get_all_by_photographer(42)
      expect(sql).to include('42')
    end

    it 'orders by year descending then filename ascending' do
      sql = Picture.get_all_by_photographer(1)
      expect(sql).to match(/ORDER BY year DESC, filename ASC/i)
    end

    it 'is vulnerable to SQL injection via the photographer_id parameter' do
      injected = '1 OR 1=1'
      sql = Picture.get_all_by_photographer(injected)
      expect(sql).to include(injected)
    end
  end
end
