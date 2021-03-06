require 'test_helper'

class ChatSessionTest < ActiveSupport::TestCase

  test 'Create a simple ChatSession' do
    chat_session = ChatSession.new(
      user: users(:admin),
      bot: bots(:weather_bot)
    )
    assert chat_session.save
  end


  test 'locale validation' do
    chat_session = ChatSession.new(
      user: users(:admin),
      bot: bots(:weather_bot)
    )
    assert chat_session.save
    assert_equal 'en-US', chat_session.locale

    chat_session.locale = "missing key"
    assert_not chat_session.save
    expected = ["Locale is not included in the list"]
    assert_equal expected, chat_session.errors.full_messages
  end


  test 'Check expired chat session' do
    old_session = chat_sessions(:one)
    assert ChatSession.create(
      user: users(:admin),
      bot: bots(:terminator_bot)
    )
    assert_not old_session.expired?

    assert ChatSession.create(
      user: users(:admin),
      bot: bots(:weather_bot)
    )
    assert old_session.expired?
  end


  test 'Update session date on new statement' do
    session = chat_sessions(:one)
    previous_updated_at = session.updated_at
    previous_created_at = session.created_at
    ChatStatement.create(
      speaker: ChatStatement.speakers[:user],
      nature: ChatStatement.natures[:text],
      content: {
        text: 'A statement'
      },
      chat_session: session
    )
    assert_not_equal previous_updated_at, session.updated_at
    assert_equal previous_created_at, session.created_at
  end
end
