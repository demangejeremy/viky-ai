class EntitiesList < ApplicationRecord
  include Colorable
  include Positionable
  positionable_ancestor :agent
  include Movable

  extend FriendlyId
  friendly_id :listname, use: :history, slug_column: 'listname'

  belongs_to :agent, touch: true
  has_many :entities, dependent: :destroy
  has_many :interpretation_aliases, as: :interpretation_aliasable, dependent: :destroy

  enum proximity: ExpressionProximity::PROXIMITIES, _prefix: :proximity

  enum visibility: [:is_public, :is_private]

  validates :listname, uniqueness: { scope: [:agent_id] },
                       length: { in: 3..30 },
                       presence: true

  before_validation :clean_listname

  after_commit do
    agent.need_nlp_sync
  end

  def slug
    "#{agent.slug}/entities_lists/#{listname}"
  end

  def to_csv
    options = {
      headers: [
        I18n.t('activerecord.attributes.entity.terms'),
        I18n.t('activerecord.attributes.entity.auto_solution_enabled'),
        I18n.t('activerecord.attributes.entity.solution')
      ],
      write_headers: true
    }
    CSV.generate(options) do |csv|
      entities.order(position: :desc).each do |entity|
        terms = entity.terms
                      .collect { |t| t['locale'] == Locales::ANY ? t['term'] : "#{t['term']}:#{t['locale']}" }
                      .join('|')
        csv << [terms, entity.auto_solution_enabled, entity.solution]
      end
    end
  end

  def from_csv(entities_import)
    entities_import.proceed(self)
  end

  def aliased_intents
    Intent.where(agent_id: agent_id)
          .joins(interpretations: :interpretation_aliases)
          .where(interpretation_aliases: { interpretation_aliasable: self })
          .distinct
          .order('position desc, created_at desc')
  end

  def proximity
    @proximity ||= ExpressionProximity.new(read_attribute(:proximity))
  end

  private

    def clean_listname
      return if listname.nil?
      self.listname = listname.parameterize(separator: '-')
    end
end
