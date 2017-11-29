class InterpretationsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:update_positions]
  before_action :set_agent
  before_action :check_user_rights
  before_action :set_intent
  before_action :set_interpretation, except: [:create, :update_positions]

  def create
    interpretation = Interpretation.new(interpretation_params)
    interpretation.intent = @intent
    @current_locale = interpretation.locale
    respond_to do |format|
      if interpretation.save
        format.js do
          @html_form = render_to_string(partial: 'form', locals: { intent: @intent, agent: @agent, interpretation: Interpretation.new, current_locale: @current_locale })
          @html = render_to_string(partial: 'interpretation', locals: { interpretation: interpretation })
          render partial: 'create_succeed'
        end
      else
        format.js do
          @html_form = render_to_string(partial: 'form', locals: { intent: @intent, agent: @agent, interpretation: interpretation, current_locale: @current_locale })
          render partial: 'create_failed'
        end
      end
    end
  end

  def show
    respond_to do |format|
      format.js {
        @show = render_to_string(partial: 'interpretation', locals: { interpretation: @interpretation })
        render partial: 'show'
      }
    end
  end

  def edit
    respond_to do |format|
      format.js {
        @form = render_to_string(partial: 'edit.html', locals: { interpretation: @interpretation })
        render partial: 'edit'
      }
    end
  end

  def update
    respond_to do |format|
      if @interpretation.update(interpretation_params)
        format.js {
          @show = render_to_string(partial: 'interpretation', locals: { interpretation: @interpretation })
          render partial: 'show'
        }
      else
        format.js do
          @form = render_to_string(partial: 'edit.html', locals: { interpretation: @interpretation })
          render partial: 'edit'
        end
      end
    end
  end

  def destroy
    respond_to do |format|
      if @interpretation.destroy
        format.js { render partial: 'destroy_succeed' }
      else
        format.js { render partial: 'destroy_failed' }
      end
    end
  end

  def update_positions
    params[:ids].reverse.each_with_index do |id, position|
      interpretation = Interpretation.find(id)
      interpretation.update(position: position)
    end
  end

  private

    def set_agent
      @agent = Agent.friendly.find(params[:agent_id])
    end

    def set_intent
      @intent = @agent.intents.friendly.find(params[:intent_id])
    end

  def set_interpretation
    @interpretation = @intent.interpretations.find(params[:id])
  end

    def interpretation_params
      params.require(:interpretation).permit(
        :expression, :locale, :keep_order, :glued, :solution,
        :interpretation_aliases_attributes => [
          :id, :nature, :position_start, :position_end, :aliasname, :intent_id, :_destroy
        ]
      )
    end

    def check_user_rights
      case action_name
      when 'show'
        access_denied unless current_user.can? :show, @agent
      when 'create', 'edit', 'update', 'destroy', 'update_positions'
        access_denied unless current_user.can? :edit, @agent
      else
        access_denied
      end
    end
end
