require_relative '../../_lib/user'

RSpec.describe User do
  let(:user_data) { { 'id' => 7, 'name' => 'Alice Smith' } }

  subject(:user) { User.new(user_data) }

  describe '#initialize' do
    it 'sets the id' do
      expect(user.instance_variable_get(:@id)).to eq(7)
    end

    it 'sets the name' do
      expect(user.instance_variable_get(:@name)).to eq('Alice Smith')
    end
  end

  describe '#insert_sql' do
    it 'uses parameterized placeholders' do
      expect(user.insert_sql).to include('VALUES (?, ?)')
    end

    it 'targets the users table with INSERT OR REPLACE' do
      expect(user.insert_sql).to include('INSERT OR REPLACE INTO users')
    end

    it 'does not embed literal values in the SQL' do
      expect(user.insert_sql).not_to include('Alice')
    end
  end

  describe '#values' do
    it 'returns [id, name]' do
      expect(user.values).to eq([7, 'Alice Smith'])
    end
  end

  describe '.create_table_sql' do
    it 'creates a users table' do
      expect(User.create_table_sql).to include('create table users')
    end

    it 'defines id as a unique primary key' do
      expect(User.create_table_sql).to include('id INT UNIQUE PRIMARY KEY')
    end
  end
end
