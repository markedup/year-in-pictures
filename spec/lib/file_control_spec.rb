require 'uri'
require 'fileutils'
require_relative '../../_lib/config'
require_relative '../../_lib/year'
require_relative '../../_lib/file_control'

RSpec.describe FileControl do
  describe '.download_all_pictures_data' do
    let(:io_double)  { double('IO', read: "---\npictures: []\n") }
    let(:uri_double) { double('URI::HTTP', open: io_double) }

    before do
      allow(Config).to receive(:year_range).and_return(2017..2020)
      allow(Config).to receive(:pictures_yaml_url).and_return('http://example.com/yaml')
      allow(Config).to receive(:source_file_from_year_path).and_return('/tmp/test.yml')
      allow(File).to receive(:write)
    end

    it 'skips years 2015 through 2018' do
      # year_range is 2017..2020, so 2017 and 2018 are skipped;
      # only 2019 and 2020 trigger a download.
      expect(URI).to receive(:parse).exactly(2).times.and_return(uri_double)
      FileControl.download_all_pictures_data
    end

    it 'writes downloaded content to disk for each processed year' do
      allow(URI).to receive(:parse).and_return(uri_double)
      expect(File).to receive(:write).exactly(2).times
      FileControl.download_all_pictures_data
    end
  end

  describe '.download_latest_pictures_data' do
    let(:io_double)  { double('IO', read: "---\npictures: []\n") }
    let(:uri_double) { double('URI::HTTP', open: io_double) }

    before do
      allow(Year).to receive(:last_year).and_return(2025)
      allow(Config).to receive(:pictures_yaml_url).with(2025).and_return('http://example.com/2025')
      allow(Config).to receive(:source_file_from_year_path).with(2025).and_return('_db/data/2025.yml')
      allow(URI).to receive(:parse).and_return(uri_double)
      allow(File).to receive(:write)
    end

    it 'downloads data for the last year only' do
      expect(URI).to receive(:parse).once
      FileControl.download_latest_pictures_data
    end

    it 'writes the downloaded content to the correct file' do
      expect(File).to receive(:write).with('_db/data/2025.yml', "---\npictures: []\n")
      FileControl.download_latest_pictures_data
    end
  end

  describe '.optimise_thumbnails' do
    before do
      allow(Time).to receive(:now).and_return(Time.new(2025, 6, 15))
      allow(FileControl).to receive(:system)
    end

    it 'calls jpegoptim on the thumbnails directory' do
      expected_dir = Config.thumbnails_directory(Config.last_month)
      expect(FileControl).to receive(:system).with("jpegoptim -sq #{expected_dir}/*.jpg")
      FileControl.optimise_thumbnails
    end
  end

  describe '.copy_main_pics' do
    let(:source_pics) { ['/source/2025/05/photo1.jpg', '/source/2025/05/photo2.jpg'] }

    before do
      allow(Time).to receive(:now).and_return(Time.new(2025, 6, 15))
      allow(ENV).to receive(:fetch).with('YIP_IMAGE_SOURCE_DIR').and_return('/source')
      allow(Dir).to receive(:[]).and_return(source_pics)
      allow(FileUtils).to receive(:cp)
    end

    it 'copies every found image to the destination directory' do
      dest = Config.image_directory(Config.last_month)
      expect(FileUtils).to receive(:cp).with('/source/2025/05/photo1.jpg', dest)
      expect(FileUtils).to receive(:cp).with('/source/2025/05/photo2.jpg', dest)
      FileControl.copy_main_pics
    end
  end

  describe '.copy_thumbnails' do
    let(:source_thumbs) { ['/source/2025/05/thumbnails/tn1.jpg'] }

    before do
      allow(Time).to receive(:now).and_return(Time.new(2025, 6, 15))
      allow(ENV).to receive(:fetch).with('YIP_IMAGE_SOURCE_DIR').and_return('/source')
      allow(Dir).to receive(:[]).and_return(source_thumbs)
      allow(FileUtils).to receive(:cp)
    end

    it 'copies each thumbnail to the thumbnails destination directory' do
      dest = Config.thumbnails_directory(Config.last_month)
      expect(FileUtils).to receive(:cp).with('/source/2025/05/thumbnails/tn1.jpg', dest)
      FileControl.copy_thumbnails
    end
  end
end
