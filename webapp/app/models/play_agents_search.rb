class PlayAgentsSearch
  attr_reader :user_id, :options

  DEFAULT_CRITERIA = {
    'query' => '',
    'selected' => 'all',
    'selected_ids' => [],
    'filter_owner' => 'all'
  }.with_indifferent_access.freeze

  def initialize(user, options = {})
    @user = user
    @options = build_options(user, options)
  end

  def self.keys
    ['user_id', 'query', 'selected', 'selected_ids', 'filter_owner']
  end

  keys.each do |meth|
    define_method(meth) { options[meth.to_sym] }
  end

  private

    def build_options(user, http_options)
      cleaned_http_options = clean_options(http_options)
      final_options = DEFAULT_CRITERIA.merge(cleaned_http_options)
      final_options[:user_id] = user.id.strip
      final_options
    end

    def clean_options(options)
      (options || {}).transform_values do |v|
        if v.respond_to?(:strip)
          v.strip
        elsif v.respond_to?(:reject)
          v.reject { |item| item.blank? }
        else
          v
        end
      end
    end

end
