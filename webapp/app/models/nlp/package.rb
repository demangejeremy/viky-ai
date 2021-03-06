require 'net/http'
include ActiveSupport::Benchmarkable

class Nlp::Package
  # Used to disable nlp sync if necessary via
  # Nlp::Package.sync_active = false
  class_attribute :sync_active
  self.sync_active = true

  VERSION = 4 # Used to invalidate cache

  JSON_HEADERS = {"Content-Type" => "application/json", "Accept" => "application/json"}

  REDIS_URL = ENV.fetch("VIKYAPP_REDIS_PACKAGE_NOTIFIER") { 'redis://localhost:6379/3' }

  def initialize(agent, cache = Rails.cache)
    @agent = agent
    @cache = cache
  end

  def self.reinit
    return if Rails.env.test?
    unless Nlp::Package.sync_active
      Rails.logger.info '  Skipping push_all packages to NLP because sync is deactivated'
      return
    end
    event = :reinit
    redis_opts = {
      url: REDIS_URL
    }
    redis = Redis.new(redis_opts)
    redis.publish(:viky_packages_change_notifications, { event: event }.to_json)
    Rails.logger.info "  | Redis notify agent's #{event}"
  end

  def destroy
    return if Rails.env.test?
    unless Nlp::Package.sync_active
      Rails.logger.info "  Skipping destroy of package #{@agent.id} to NLP because sync is deactivated"
      return
    end
    notify(:delete)
  end

  def push
    return if Rails.env.test?
    unless Nlp::Package.sync_active
      Rails.logger.info "  Skipping push of package #{@agent.id} to NLP because sync is deactivated"
      return
    end
    notify(:update)
  end

  def generate_json(io)
    encoder = io.instance_of?(JsonChunkEncoder) ? io : JsonChunkEncoder.new(io)
    encoder.wrap_object do
      encoder.write_value('id', @agent.id)
      encoder.write_value('slug', @agent.slug)
      encoder.wrap_array('interpretations') do
        write_interpretation(encoder)
        write_entities_list(encoder)
      end
    end
  end

  def full_json_export(io)
    packages_list = full_packages_map(@agent).values
    encoder = JsonChunkEncoder.new io
    encoder.wrap_array do
      packages_list.each do |package|
        Nlp::Package.new(package).generate_json(encoder)
      end
    end
  end

  def logger
    Rails.logger
  end


  private

    def notify event
      redis_opts = {
        url: REDIS_URL
      }
      redis = Redis.new(redis_opts)
      redis.publish(:viky_packages_change_notifications, { event: event, id: @agent.id }.to_json  )
      Rails.logger.info "  | Redis notify agent's #{event} #{@agent.id}"
    end

    def full_packages_map(agent)
      return { agent.id => agent } if agent.successors.nil?
      result = { agent.id => agent }
      agent.successors.each do |successor|
        result.merge! full_packages_map(successor)
      end
      result
    end

    def write_interpretation(encoder)
      @agent.interpretations.order(position: :desc).each do |interpretation|
        cache_key = ['pkg', VERSION, @agent.slug, 'interpretation'.freeze, interpretation.id, (interpretation.updated_at.to_f * 1000).to_i].join('/')
        build_internals_list_nodes(interpretation, encoder, cache_key)
        build_interpretation(interpretation, encoder, cache_key)
      end
    end

    def write_entities_list(encoder)
      @agent.entities_lists.order(position: :desc).each do |elist|
        build_entities_list(elist, encoder)
      end
    end

    def build_internals_list_nodes(interpretation, encoder, cache_key)
      cache_key = "#{cache_key}/build_internals_list_nodes"
      if @cache.exist? cache_key
        formulations = @cache.read cache_key
        encoder.write_string formulations
      else
        FormulationAlias
          .includes(:formulation)
          .where(is_list: true, formulations: { interpretation_id: interpretation.id })
          .order('formulations.position DESC, formulations.locale ASC')
          .order(:position_start).each do |ialias|

          formulation_hash = {}
          formulation_hash['id']   = "#{ialias.formulation_aliasable.id}_#{ialias.id}_recursive"
          formulation_hash['slug'] = "#{ialias.formulation_aliasable.slug}_#{ialias.id}_recursive"
          formulation_hash['scope'] = 'hidden'

          expressions = []

          expression = {}
          expression['expression'] = "@{#{ialias.aliasname}}"
          expression['pos'] = ialias.formulation.position
          expression['aliases'] = []
          expression['aliases'] << build_internal_alias(ialias)
          expression['keep-order'] = ialias.formulation.keep_order if ialias.formulation.keep_order
          expression['glue-distance'] = ialias.formulation.proximity.get_distance
          expression['glue-strength'] = 'punctuation'.freeze if ialias.formulation.proximity_accepts_punctuations?
          expressions << expression

          expression = {}
          expression['expression'] = "@{#{ialias.aliasname}} @{#{ialias.aliasname}_recursive}"
          expression['pos'] = ialias.formulation.position
          expression['aliases'] = []
          expression['aliases'] << build_internal_alias(ialias)
          expression['aliases'] << build_internal_alias(ialias, true)
          expression['keep-order'] = ialias.formulation.keep_order if ialias.formulation.keep_order
          expression['glue-distance'] = ialias.formulation.proximity.get_distance
          expression['glue-strength'] = 'punctuation'.freeze if ialias.formulation.proximity_accepts_punctuations?
          expressions << expression

          formulation_hash[:expressions] = expressions
          encoder.write_object(formulation_hash, cache_key)
        end
        payload = encoder.withdraw_cache_payload(cache_key)
        @cache.write(cache_key, payload) if payload.present?
      end
    end

    def build_interpretation(interpretation, encoder, cache_key)
      cache_key = "#{cache_key}/build_node"
      encoder.wrap_object do
        encoder.write_value('id', interpretation.id)
        encoder.write_value('slug', interpretation.slug)
        encoder.write_value('scope', interpretation.is_public? ? 'public' : 'private')
        encoder.wrap_array('expressions') do
          if @cache.exist? cache_key
            expressions = @cache.read cache_key
            encoder.write_string expressions
          else
            interpretation.formulations.order(position: :desc, locale: :asc).each do |formulation|
              expression = {}
              expression['expression']    = formulation.expression_with_aliases
              expression['pos']           = formulation.position
              aliases = build_aliases(formulation)
              expression['aliases']       = aliases unless aliases.empty?
              expression['locale']        = formulation.locale unless formulation.locale == Locales::ANY
              expression['keep-order']    = formulation.keep_order if formulation.keep_order
              expression['glue-distance'] = formulation.proximity.get_distance
              expression['glue-strength'] = 'punctuation'.freeze if formulation.proximity_accepts_punctuations?
              solution = build_formulation_solution(formulation)
              expression['solution']      = solution unless solution.blank?

              encoder.write_object(expression, cache_key)

              formulation.formulation_aliases
                .where(any_enabled: true, is_list: false)
                .order(position_start: :asc).each do |ialias|
                any_node = build_any_node(ialias, expression)
                encoder.write_object(any_node, cache_key)
              end
            end
            payload = encoder.withdraw_cache_payload(cache_key)
            @cache.write(cache_key, payload) if payload.present?
          end
        end
      end
    end

    def build_entities_list(elist, encoder)
      cache_key_base = [
        'pkg',
        VERSION,
        @agent.slug,
        'entities_list'.freeze,
        elist.id,
        elist.proximity,
        'entities'.freeze,
        'build_node'.freeze
      ].join('/').freeze
      encoder.wrap_object do
        encoder.write_value('id', elist.id)
        encoder.write_value('slug', elist.slug)
        encoder.write_value('scope', elist.is_public? ? 'public' : 'private')
        encoder.wrap_array('expressions') do
          elist.entities_in_ordered_batchs.each do |batch, max_position, min_position|
            last_updated = batch.unscope(:order).pluck(Arel.sql 'MAX("entities"."updated_at")').first
            cache_key = "#{cache_key_base}/#{(last_updated.to_f * 1000).to_i}?from=#{min_position}&to=#{max_position}"
            if @cache.exist? cache_key
              expressions = @cache.read cache_key
              encoder.write_string expressions
            else
              elist_proximity_distance = elist.proximity.get_distance
              elist_proximity_is_glued = elist.proximity_glued?
              batch.select('terms, position, auto_solution_enabled, solution, case_sensitive, accent_sensitive').each do |entity|
                entity.terms.each do |term|
                  expression = {}
                  expression[:expression] = term['term']
                  expression[:pos] = entity.position
                  expression[:locale] = term['locale'] unless term['locale'] == Locales::ANY
                  expression[:solution] = build_entities_list_solution(entity)
                  expression['keep-order'] = true
                  expression['glue-distance'] = elist_proximity_distance
                  expression['glue-strength'] = 'punctuation'.freeze if elist_proximity_is_glued
                  expression['case-sensitive'] = entity.case_sensitive if entity.case_sensitive
                  expression['accent-sensitive'] = entity.accent_sensitive if entity.accent_sensitive
                  encoder.write_object(expression, cache_key)
                end
              end
              payload = encoder.withdraw_cache_payload(cache_key)
              @cache.write(cache_key, payload) if payload.present?
            end
          end
        end
      end
    end

    def build_any_node(ialias, expression)
      any_aliasname = ialias.aliasname
      any_expression = expression.deep_dup
      old_aliases = expression['aliases']
      any_expression['aliases'] = []
      old_aliases.each do |jsonalias|
        if jsonalias['alias'] == any_aliasname
          any_expression['aliases'] << {
            'alias': any_aliasname,
            'type': 'any'
          }
        else
          any_expression['aliases'] << jsonalias
        end
      end
      any_expression
    end

    def build_internal_alias(ialias, recursive=false)
      if recursive
        {
          'alias': "#{ialias.aliasname}_recursive",
          'slug': "#{ialias.formulation_aliasable.slug}_#{ialias.id}_recursive",
          'id': "#{ialias.formulation_aliasable.id}_#{ialias.id}_recursive",
          'package': @agent.id
        }
      else
        {
          'alias': ialias.aliasname,
          'slug': ialias.formulation_aliasable.slug,
          'id': ialias.formulation_aliasable.id,
          'package': @agent.id
        }
      end
    end

    def build_aliases(formulation)
      formulation.formulation_aliases
        .order(:position_start)
        .collect { |ialias| build_alias(ialias) }
    end

    def build_alias(ialias)
      result = {}
      result['alias'] = ialias.aliasname
      if ialias.type_number?
        result['type'] = 'number'
      elsif ialias.type_regex?
        result['type'] = 'regex'
        result['regex'] = ialias.reg_exp
      else
        result['package'] = @agent.id
        if ialias.is_list
          result['slug'] = "#{ialias.formulation_aliasable.slug}_#{ialias.id}_recursive"
          result['id'] = "#{ialias.formulation_aliasable.id}_#{ialias.id}_recursive"
        else
          result['slug'] = ialias.formulation_aliasable.slug
          result['id'] = ialias.formulation_aliasable.id
        end
      end
      result
    end

    def build_formulation_solution(formulation)
      if formulation.auto_solution_enabled and formulation.formulation_aliases.empty?
        formulation.expression
      elsif formulation.solution.present?
        "`#{formulation.solution}`"
      else
        ''
      end
    end

    def build_entities_list_solution(entity)
      if entity.auto_solution_enabled
        entity.terms.first['term']
      elsif entity.solution.present?
        "`#{entity.solution}`"
      else
        ''
      end
    end
end
