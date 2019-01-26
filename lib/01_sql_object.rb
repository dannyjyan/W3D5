require_relative 'db_connection'
require 'active_support/inflector'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    return @columns if @columns
    columns = DBConnection.execute2(<<-SQL).first
      SELECT
        *
      FROM 
        #{table_name}
      LIMIT 0
    SQL
    columns.map!(&:to_sym)
    @columns = columns #only queries database once 
    # ...
  end

  def self.finalize!
    self.columns.each do |column|
      define_method(column) do  #get
        self.attributes[column]
      end 

      define_method("#{column}=") do |value| #set
        self.attributes[column] = value
      end 
    end 
  end

  def self.table_name=(table_name)
    # ...
    @table_name = table_name
  end

  def self.table_name
    @table_name || self.name.tableize
    # ...
  end

  def self.all
    results = DBConnection.execute(<<-SQL)
      SELECT
        #{self.table_name}.* 
      FROM
        #{self.table_name}
    SQL
    parse_all(results)
  end

  def self.parse_all(results)
    results.map {|result| self.new(result)}
    # ...
  end

  def self.find(id)
    row = DBConnection.execute(<<-SQL, id)
      SELECT 
        #{table_name}.*
      FROM
        #{table_name}
      WHERE 
        #{table_name}.id = ?
    SQL
    parse_all(row).first
    # ...
  end

  def initialize(params = {})
    params.each do |attr, value| 
      sym = attr.to_sym
      raise "unknown attribute '#{attr}'" unless self.class.columns.include?(sym)
      self.send("#{attr}=", value)
    end 
    # ...
  end

  def attributes
    @attributes ||= {}
    # ...
  end

  def attribute_values
    p self.class.columns.map {|attr| self.send(attr)}
    # ...
  end

  def insert
    column = self.class.columns.drop(1)
    question_marks = ["?"]*(column.length)
    column_names = column.map(&:to_s).join(",")
    question_marks = question_marks.join(",")
    DBConnection.execute(<<-SQL, *attribute_values.drop(1))
      INSERT INTO 
        #{self.class.table_name} (#{column_names})
      VALUES 
        (#{question_marks})
    SQL
    self.id = DBConnection.last_insert_row_id
    # ...
  end

  def update
    column = self.class.columns.drop(1)
    columns_set = column.map{|name| "#{name} = ?"}.join(",")

    DBConnection.execute(<<-SQL, *attribute_values.drop(1), id)
      UPDATE
        #{self.class.table_name}
      SET
        #{columns_set}
      WHERE
        #{self.class.table_name}.id = ?
    SQL
  end

  def save
    id.nil? ? insert : update 
    # ...
  end
end
