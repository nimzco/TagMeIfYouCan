class Status < ActiveRecord::Base
  has_one :tags_facebook
  
  validates :name, :uniqueness => true
  
  def self.pending
    where(:name => 'pending').first
  end
  def self.validated
    where(:name => 'validated').first
  end
  def self.rejected
    where(:name => 'rejected').first
  end

end
