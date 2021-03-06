class ChatStatementsController < ApplicationController
  before_action :set_bot
  before_action :check_user_rights
  before_action :set_session

  def index
    offset = params['start'].present? ? params['start'] : 0
    respond_to do |format|
      format.json {
        render json: @chat_session.chat_statements.where(speaker: :user).reorder(created_at: :desc).limit(10).offset(offset) if @chat_session.present?
      }
    end
  end

  def create
    @content = statement_params[:content]
    @chat_statement = ChatStatement.new(
      chat_session: @chat_session,
      speaker: :user,
      nature: :text,
      content: {
        text: @content
      }
    )
    respond_to do |format|
      format.js {
        render partial: 'create_succeed' if @chat_statement.save
      }
    end
  end

  def user_action
    case params[:type]
    when 'click_button'
      BotSendUserStatementJob.perform_later(@chat_session.id, 'click_button', {
        statement_id: params[:statement_id],
        button_index: params[:button_index],
        payload:      params[:payload]
      })
    when 'locate'
      BotSendUserStatementJob.perform_later(@chat_session.id, 'locate', {
        status: params[:status],
        location: params[:location]
      })
    end
    respond_to do |format|
      format.js {
        render partial: 'user_action'
      }
    end
  end


  private

    def statement_params
      params.require(:statement).permit(:content)
    end

    def set_bot
      @bot = Bot.find(params[:chatbot_id])
    end

    def set_session
      @chat_session = ChatSession.where(user: current_user, bot: @bot).last
    end

    def check_user_rights
      access_denied unless current_user.can?(:edit, @bot.agent) || (current_user.can?(:show, @bot.agent) && !@bot.wip_enabled)
    end

end
