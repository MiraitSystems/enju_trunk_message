# -*- encoding: utf-8 -*-
class Agent < ActiveRecord::Base
  scope :readable_by, lambda{|user| {:conditions => ['required_role_id <= ?', user.try(:user_has_role).try(:role_id) || Role.where(:name => 'Guest').select(:id).first.id]}}
  belongs_to :user
  belongs_to :agent_type
  belongs_to :required_role, :class_name => 'Role', :foreign_key => 'required_role_id', :validate => true

  validates_presence_of :agent_type
  validates_associated :agent_type
  validates :full_name, :presence => true, :length => {:maximum => 255}
  validates :user_id, :uniqueness => true, :allow_nil => true
  validates :email, :format => {:with => /^([\w\.%\+\-]+)@([\w\-]+\.)+([\w]{2,})$/i}, :allow_blank => true
  before_validation :set_role_and_name, :on => :create

  #has_paper_trail
  attr_accessor :user_username
  #[:address_1, :address_2].each do |column|
  #  encrypt_with_public_key column,
  #    :key_pair => File.join(Rails.root.to_s,'config','keypair.pem'),
  #    :base64 => true
  #end

  searchable do
    text :name, :place, :address_1, :address_2, :other_designation, :note
    string :zip_code_1
    string :zip_code_2
    string :username do
      user.username if user
    end
    time :created_at
    time :updated_at
    string :user
    integer :work_ids, :multiple => true
    integer :expression_ids, :multiple => true
    integer :manifestation_ids, :multiple => true
    integer :agent_merge_list_ids, :multiple => true if defined?(EnjuResourceMerge)
    integer :original_agent_ids, :multiple => true
    integer :required_role_id
    integer :agent_type_id
  end

  def self.per_page
    10
  end

  def full_name_without_space
    full_name.gsub(/\s/, "")
  end

  def set_role_and_name
    self.required_role = Role.where(:name => 'Librarian').first if self.required_role_id.nil?
    set_full_name
  end

  def set_full_name
    if self.full_name.blank?
      if self.last_name.to_s.strip and self.first_name.to_s.strip and Setting.family_name_first == true
        self.full_name = [last_name, middle_name, first_name].compact.join(" ").to_s.strip
      else
        self.full_name = [first_name, last_name, middle_name].compact.join(" ").to_s.strip
      end
    end
    if self.full_name_transcription.blank?
      self.full_name_transcription = [last_name_transcription, middle_name_transcription, first_name_transcription].join(" ").to_s.strip
    end
    [self.full_name, self.full_name_transcription]
  end

  def full_name_without_space
    full_name.gsub(/\s/, "")
  #  # TODO: 日本人以外は？
  #  name = []
  #  name << self.last_name.to_s.strip
  #  name << self.middle_name.to_s.strip
  #  name << self.first_name.to_s.strip
  #  name << self.corporate_name.to_s.strip
  #  name.join("").strip
  end

  def full_name_transcription_without_space
    full_name_transcription.to_s.gsub(/\s/, "")
  end

  def full_name_alternative_without_space
    full_name_alternative.to_s.gsub(/\s/, "")
  end

  def name
    name = []
    name << full_name.to_s.strip
    name << full_name_transcription.to_s.strip
    name << full_name_alternative.to_s.strip
    #name << full_name_without_space
    #name << full_name_transcription_without_space
    #name << full_name_alternative_without_space
    #name << full_name.wakati rescue nil
    #name << full_name_transcription.wakati rescue nil
    #name << full_name_alternative.wakati rescue nil
    name
  end

  def date
    if date_of_birth
      if date_of_death
        "#{date_of_birth} - #{date_of_death}"
      else
        "#{date_of_birth} -"
      end
    end
  end

  def creator?(resource)
    resource.creators.include?(self)
  end

  def publisher?(resource)
    resource.publishers.include?(self)
  end

  def check_required_role(user)
    return true if self.user.blank?
    return true if self.user.required_role.name == 'Guest'
    return true if user == self.user
    return true if user.has_role?(self.user.required_role.name)
    false
  rescue NoMethodError
    false
  end

  def created(work)
    creates.where(:work_id => work.id).first
  end

  def realized(expression)
    realizes.where(:expression_id => expression.id).first
  end

  def produced(manifestation)
    produces.where(:manifestation_id => manifestation.id).first
  end

  def owned(item)
    owns.where(:item_id => item.id)
  end

  def self.import_agents(agent_lists)
    list = []
    agent_lists.each do |agent_list|
      agent = Agent.where(:full_name => agent_list[:full_name]).first
      unless agent
        agent = Agent.new(
          :full_name => agent_list[:full_name],
          :full_name_transcription => agent_list[:full_name_transcription],
          :language_id => 1
        )
        agent.required_role = Role.where(:name => 'Guest').first
        agent.save
      end
      list << agent
    end
    list
  end

  def agents
    self.original_agents + self.derived_agents
  end
end
