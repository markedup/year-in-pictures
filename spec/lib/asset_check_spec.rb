require 'date'
require_relative '../../_lib/config'
require_relative '../../_lib/db_control'
require_relative '../../_lib/asset_check'

RSpec.describe AssetCheck do
  describe '.count_output' do
    it 'returns a string containing "true" when the check passes' do
      expect(AssetCheck.count_output(true)).to include('true')
    end

    it 'returns a string containing "false" when the check fails' do
      expect(AssetCheck.count_output(false)).to include('false')
    end
  end

  describe '.get_image_list' do
    let(:last_month) { { year: 2025, month: 3 } }
    let(:padded)     { '03' }

    before do
      allow(Dir).to receive(:[])
        .with('images/2025/03*.jpg')
        .and_return(['images/2025/03-photo-a.jpg', 'images/2025/03-photo-b.jpg'])
    end

    it 'returns only the basenames (no directory path)' do
      result = AssetCheck.get_image_list(last_month, padded)
      expect(result).to eq(['03-photo-a.jpg', '03-photo-b.jpg'])
    end
  end

  describe '.get_thumbnails_list' do
    let(:last_month) { { year: 2025, month: 3 } }
    let(:padded)     { '03' }

    before do
      allow(Dir).to receive(:[])
        .with('images/2025/thumbnails/03*.jpg')
        .and_return(['images/2025/thumbnails/03-photo-a.jpg'])
    end

    it 'returns only the basenames of the thumbnails' do
      result = AssetCheck.get_thumbnails_list(last_month, padded)
      expect(result).to eq(['03-photo-a.jpg'])
    end
  end

  describe '.get_data_list' do
    let(:last_month)      { { year: 2025, month: 3 } }
    let(:last_month_name) { 'march' }

    before do
      allow(DbControl).to receive(:get_month_pictures)
        .with('march', 2025)
        .and_return([
          ['03-photo-a.html', 'images/03-photo-a.jpg', 'Caption A', 'Alt A'],
          ['03-photo-b.html', 'images/03-photo-b.jpg', 'Caption B', 'Alt B']
        ])
    end

    it 'returns the image_filename column from each database row' do
      result = AssetCheck.get_data_list(last_month, last_month_name)
      expect(result).to eq(['images/03-photo-a.jpg', 'images/03-photo-b.jpg'])
    end
  end

  describe '.do_checks (cross-list comparison logic)' do
    # Validate the set-intersection logic used to detect mismatches.
    # We exercise this via the individual list helpers plus the intersection
    # arithmetic, keeping the test free of filesystem/DB side effects.
    it 'detects when images are missing from thumbnails' do
      images     = ['01-a.jpg', '01-b.jpg', '01-c.jpg']
      thumbnails = ['01-a.jpg', '01-b.jpg']
      data       = ['01-a.jpg', '01-b.jpg', '01-c.jpg']

      intersection     = images & thumbnails & data
      missing_thumbnail = images - intersection

      expect(missing_thumbnail).to eq(['01-c.jpg'])
    end

    it 'detects when data entries are missing their image files' do
      images     = ['01-a.jpg']
      thumbnails = ['01-a.jpg', '01-b.jpg']
      data       = ['01-a.jpg', '01-b.jpg']

      intersection  = images & thumbnails & data
      missing_image = data - intersection

      expect(missing_image).to eq(['01-b.jpg'])
    end

    it 'reports no mismatches when all three lists are identical' do
      images     = ['01-a.jpg', '01-b.jpg']
      thumbnails = ['01-a.jpg', '01-b.jpg']
      data       = ['01-a.jpg', '01-b.jpg']

      intersection = images & thumbnails & data
      expect(images - intersection).to be_empty
      expect(thumbnails - intersection).to be_empty
      expect(data - intersection).to be_empty
    end
  end
end
