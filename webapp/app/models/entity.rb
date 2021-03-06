class Entity < ApplicationRecord
  include Positionable
  positionable_ancestor :entities_list

  include ActionView::Helpers::NumberHelper

  belongs_to :entities_list, touch: true, counter_cache: true

  validates :solution, length: { maximum: 2000 }
  validates :solution, presence: true, if: -> { self.auto_solution_enabled }
  validates :terms, length: { maximum: 5000 }, presence: true
  validate :validate_locales_exists
  validate :validate_terms_present
  validate :validate_terms_length_in_bytes
  validate :validate_expression_nlp_length
  validate :validate_owner_quota, on: :create, if: -> { Feature.quota_enabled? }

  before_validation :parse_terms
  before_validation :build_solution
  before_validation :build_searchable_terms
  after_save :update_agent_locales
  after_create :touch_entities_list
  after_destroy :touch_entities_list

  def self.search(query = nil)
    conditions = where('1 = 1')
    unless query.blank?
      query = I18n.transliterate(query).downcase
      conditions = conditions.where('searchable_terms ilike ?', "%#{query}%")
    end
    conditions
  end

  def terms_to_s
    return '' if terms.blank?
    terms.collect { |term|
      if term['locale'] == Locales::ANY
        term['term']
      else
        "#{term['term']}:#{term['locale']}"
      end
    }.reject(&:blank?).join("\n")
  end

  def self.extract_searchable_terms(terms)
    if terms.instance_of?(Array)
      I18n.transliterate(
        terms.collect { |term| term['term'] }.join(' ')
      ).downcase
    else
      ""
    end
  end


  private

    def parse_terms
      if terms.is_a?(String) && terms.length <= 5000
        self.terms = EntityTermsParser.new(terms).proceed
      end
    end

    def build_solution
      return unless self.auto_solution_enabled
      return if self.terms.blank?
      if terms.is_a? String
        self.solution = self.terms
      else
        self.solution = self.terms.first['term']
      end
    end

    def build_searchable_terms
      self.searchable_terms = Entity.extract_searchable_terms(self.terms)
    end

    def validate_locales_exists
      return unless terms.instance_of?(Array)
      terms.each do |json|
        unless Locales::ALL.include?(json['locale'])
          errors.add(:terms, I18n.t('errors.entity.unknown_locale', current_locale: json['locale']))
        end
      end
    end

    def update_agent_locales
      agent = entities_list.agent
      entity_locales = terms.collect{|t| t["locale"]}.uniq
      agent_locales = (agent.locales + entity_locales).uniq
      if agent_locales != agent.locales
        agent.update_columns(locales: agent_locales)
      end
    end

    def validate_terms_present
      return unless terms.instance_of?(Array)
      if terms.any? { |json| json['term'].empty? }
        errors.add(:terms, I18n.t('errors.entity.term_abscent'))
      end
    end

    def validate_terms_length_in_bytes
      return unless terms.instance_of?(Array)
      terms.each do |json|
        actual_size = json['term'].bytesize
        if actual_size > 2048
          errors.add(:terms, I18n.t('errors.messages.too_large', actual: number_to_human_size(actual_size, precision: 4), count: number_to_human_size(2048, precision: 4)))
        end
      end
    end

    def validate_expression_nlp_length
      return if terms.nil?
      nlp_max_length = 36
      if terms.instance_of?(Array)
        terms_list = terms.map { |json| json['term'] }
      else
        terms_list = [terms]
      end
      return if terms_list.collect(&:size).max < nlp_max_length
      terms_list.each do |term|
        exp = term
                .gsub(/(\D)(\d)/, '\1 \2')
                .gsub(/(\d)(\D)/, '\1 \2')
                .gsub(/(\p{No})/, ' \1 ') # G_UNICODE_OTHER_NUMBER (No)
                .gsub(/(\p{Pc})/, ' \1 ') # G_UNICODE_CONNECT_PUNCTUATION (Pc)
                .gsub(/(\p{Pd})/, ' \1 ') # G_UNICODE_DASH_PUNCTUATION (Pd)
                .gsub(/(\p{Ps})/, ' \1 ') # G_UNICODE_OPEN_PUNCTUATION (Ps)
                .gsub(/(\p{Pe})/, ' \1 ') # G_UNICODE_CLOSE_PUNCTUATION (Pe)
                .gsub(/(\p{Pi})/, ' \1 ') # G_UNICODE_INITIAL_PUNCTUATION (Pi)
                .gsub(/(\p{Pf})/, ' \1 ') # G_UNICODE_FINAL_PUNCTUATION (Pf)
                .gsub(/(\p{Po})/, ' \1 ') # G_UNICODE_OTHER_PUNCTUATION (Po)
                .gsub(/(\p{Sc})/, ' \1 ') # G_UNICODE_CURRENCY_SYMBOL (Sc)
                .gsub(/(\p{Sk})/, ' \1 ') # G_UNICODE_MODIFIER_SYMBOL (Sk)
                .gsub(/(\p{Sm})/, ' \1 ') # G_UNICODE_MATH_SYMBOL (Sm)
                .gsub(/(\p{So})/, ' \1 ') # G_UNICODE_OTHER_SYMBOL (So)
                .gsub(/([\u4e00-\u9FFF])/, ' \1 ') # G_UNICODE_BREAK_IDEOGRAPHIC (ID) https://en.wikipedia.org/wiki/CJK_Unified_Ideographs_(Unicode_block)
                .gsub(Unicode::Emoji::REGEX, ' emoji ') # G_UNICODE_BREAK_EMOJI_BASE (EB) https://en.wikipedia.org/wiki/Emoji#ref_U1F602_tr51
                .gsub(/\p{Cc}/, '') # G_UNICODE_CONTROL (Cc)
                .gsub(/\p{Cf}/, '') # G_UNICODE_FORMAT (Cf)
                .gsub(/\p{Cn}/, '') # G_UNICODE_UNASSIGNED (Cn)
                .gsub(/\p{Co}/, '') # G_UNICODE_PRIVATE_USE (Co)
                .gsub(/\p{Cs}/, '') # G_UNICODE_SURROGATE (Cs)
        actual_count = exp.split.size
        errors.add(:terms, I18n.t('errors.entity.term_nlp_length', count: nlp_max_length, actual_count: actual_count)) if actual_count > nlp_max_length
      end
    end

    def validate_owner_quota
      unless entities_list.nil?
        owner = User.find(entities_list.agent.owner_id)
        if owner.quota_exceeded?
          errors.add(:quota, I18n.t('errors.entity.quota', maximum: Quota.expressions_limit))
        end
      end
    end

    def touch_entities_list
      # belongs_to :entities_list, touch: true, counter_cache: true
      # Touch option fails on entity creation and deletion.
      entities_list.touch
    end
end
