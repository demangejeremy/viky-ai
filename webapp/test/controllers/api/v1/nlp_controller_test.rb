require 'test_helper'

class NlsControllerTest < ActionDispatch::IntegrationTest

  test "Interpret route" do
    assert_routing({
      method: 'get',
      path: "api/v1/agents/admin/weather/interpret.json"
    },
    {
      format: 'json',
      controller: 'api/v1/nlp',
      action: 'interpret',
      ownername: 'admin',
      agentname: 'weather'
    })
  end


  test 'validation on ownername and agentname' do
    assert_raise ActiveRecord::RecordNotFound do
      get '/api/v1/agents/missing_user/missing_agent/interpret.json',
        params: { sentence: 'test' }
    end

    assert_raise ActiveRecord::RecordNotFound do
      get '/api/v1/agents/admin/missing_agent/interpret.json',
        params: { sentence: 'test' }
    end
  end


  test "Agent access not permitted if token not good" do
    get "/api/v1/agents/admin/weather/interpret.json",
      params: { sentence: "test" }
    assert_equal '401', response.code
    expected = ["Access denied: wrong token."]
    assert_equal expected, JSON.parse(response.body)["errors"]

    get "/api/v1/agents/admin/weather/interpret.json",
      params: { sentence: "test", agent_token: "blablabla" }
    assert_equal '401', response.code
    expected = ["Access denied: wrong token."]
    assert_equal expected, JSON.parse(response.body)["errors"]
  end


  test "Agent token can be specified in the request header and in the request parameters" do
    interpretation = interpretations(:weather_forecast)
    agent = agents(:weather)

    Nlp::Interpret.any_instance.stubs('send_nlp_request').returns(
      status: '200',
      body: {
        "interpretations" => [
          {
            "package" => agent.id,
            "id"      => interpretation.id,
            "slug"    => "weather_forecast",
            "score"   => 1.0
          }
        ]
      }
    )

    get "/api/v1/agents/admin/weather/interpret.json",
      params: { sentence: "test", agent_token: agent.api_token }
    assert_equal '200', response.code
    expected = {
      'interpretations' => [
        {
          "id"    => interpretation.id,
          "slug"  => "weather_forecast",
          "name"  => "weather_forecast",
          "score" => 1.0
        }
      ]
    }
    assert_equal expected, JSON.parse(response.body)

    get "/api/v1/agents/admin/weather/interpret.json",
      params: { sentence: "test" },
      headers: { "Agent-Token" => agent.api_token }
    assert_equal '200', response.code
    assert_equal expected, JSON.parse(response.body)
  end


  test "Agent token in the request parameters overloads agent token in the request header" do
    interpretation = interpretations(:weather_forecast)
    agent = agents(:weather)
    Nlp::Interpret.any_instance.stubs('send_nlp_request').returns(
      status: '200',
      body: {
        "interpretations" => [
          {
            "package" => agent.id,
            "id"      => interpretation.id,
            "slug"    => "weather_forecast",
            "score"   => 1.0
          }
        ]
      }
    )

    get "/api/v1/agents/admin/weather/interpret.json",
      params: { sentence: "test" },
      headers: { "Agent-Token" => agent.api_token }
    assert_equal '200', response.code

    get "/api/v1/agents/admin/weather/interpret.json",
      params: { sentence: "test", agent_token: "wrong_token" },
      headers: { "Agent-Token" => agent.api_token }
    assert_equal '401', response.code
  end


  test "An empty sentence request is unprocessable" do
    agent = agents(:weather)

    get "/api/v1/agents/admin/weather/interpret.json?agent_token=#{agent.api_token}"
    assert_equal '422', response.code
    assert_equal ["Sentence can't be blank"], JSON.parse(response.body)["errors"]
  end


  test 'Provide statistics contexts with the sentence' do
    sentence = "test context #{SecureRandom.uuid}"
    interpretation = interpretations(:weather_forecast)
    agent = agents(:weather)
    Nlp::Interpret.any_instance.stubs('send_nlp_request').returns(
      status: '200',
      body: {
        'interpretations' => [
          {
            'package' => agent.id,
            'id'      => interpretation.id,
            'slug'    => 'weather_forecast',
            'score'   => 1.0
          }
        ]
      }
    )

    get '/api/v1/agents/admin/weather/interpret.json',
        params: {
          sentence: sentence,
          agent_token: agent.api_token,
          context: {
            session_id: 'abc',
            bot_version: '1.1-a58b'
          }
        }

    expected = {
      'interpretations' => [
        {
          'id'    => interpretation.id,
          'slug'  => 'weather_forecast',
          'name'  => 'weather_forecast',
          'score' => 1.0
        }
      ]
    }
    assert_equal expected, JSON.parse(response.body)
    client = InterpretRequestLogTestClient.new
    result = client.search_documents({ match: { sentence: sentence } },1)
    found = result['hits']['hits'].first['_source'].symbolize_keys
    assert_equal 'abc', found[:context]['session_id']
    assert_equal '1.1-a58b', found[:context]['bot_version']
    assert_equal [agent.updated_at], found[:context]['agent_version']
  end


  test 'Set spellchecking' do
    interpretation = interpretations(:weather_forecast)
    agent = interpretation.agent
    Nlp::Interpret.any_instance.stubs('send_nlp_request').returns(
      status: '200',
      body: {
        'interpretations' => [
          {
            'package' => agent.id,
            'id'      => interpretation.id,
            'slug'    => 'weather_forecast',
            'score'   => 1.0
          }
        ]
      }
    )

    get '/api/v1/agents/admin/weather/interpret.json',
      params: { sentence: 'bonjoir', agent_token: agent.api_token, spellchecking: 'inactive' }
    assert_equal '200', response.code
    get '/api/v1/agents/admin/weather/interpret.json',
      params: { sentence: 'bonjoir', agent_token: agent.api_token, spellchecking: 'low' }
    assert_equal '200', response.code
    get '/api/v1/agents/admin/weather/interpret.json',
      params: { sentence: 'bonjoir', agent_token: agent.api_token, spellchecking: 'medium' }
    assert_equal '200', response.code
    get '/api/v1/agents/admin/weather/interpret.json',
      params: { sentence: 'bonjoir', agent_token: agent.api_token, spellchecking: 'high' }
    assert_equal '200', response.code
    get '/api/v1/agents/admin/weather/interpret.json',
      params: { sentence: 'bonjoir', agent_token: agent.api_token, spellchecking: 'foobar' }
    assert_equal '422', response.code
  end


  test 'Log request even when no more NLP server are available' do
    sentence = "test NLP crash #{SecureRandom.uuid}"
    agent = agents(:weather)
    Nlp::Interpret.any_instance.stubs('send_nlp_request').raises(Errno::ECONNREFUSED, 'Failed to open TCP connection')

    get '/api/v1/agents/admin/weather/interpret.json',
        params: {
          sentence: sentence,
          agent_token: agent.api_token
        }

    client = InterpretRequestLogTestClient.new
    result = client.search_documents({ match: { sentence: sentence } },1)
    found = result['hits']['hits'].first['_source'].symbolize_keys
    assert_equal 503, found[:status]
    assert_equal ['NLS temporarily unavailable', 'No more NLP server are available', 'Connection refused - Failed to open TCP connection'],
                 found[:body]['errors']
  end


  test 'Log request even when NLP has just crashed' do
    sentence = "test NLP crash #{SecureRandom.uuid}"
    agent = agents(:weather)
    Nlp::Interpret.any_instance.stubs('send_nlp_request').raises(EOFError, 'end of file reached')

    get '/api/v1/agents/admin/weather/interpret.json',
        params: {
          sentence: sentence,
          agent_token: agent.api_token
        }

    client = InterpretRequestLogTestClient.new
    result = client.search_documents({ match: { sentence: sentence } },1)
    found = result['hits']['hits'].first['_source'].symbolize_keys
    assert_equal 503, found[:status]
    assert_equal ['NLS temporarily unavailable', 'NLP have just crashed'], found[:body]['errors']
  end


  test 'Log request even when unexpected error' do
    sentence = "test NLP Big big error #{SecureRandom.uuid}"
    agent = agents(:weather)
    Nlp::Interpret.any_instance.stubs('send_nlp_request').raises(RuntimeError, 'Big big error')

    get '/api/v1/agents/admin/weather/interpret.json',
        params: {
          sentence: sentence,
          agent_token: agent.api_token
        }
    assert_response 500

    client = InterpretRequestLogTestClient.new
    result = client.search_documents({ match: { sentence: sentence } },1)
    found = result['hits']['hits'].first['_source'].symbolize_keys
    assert_equal 500, found[:status]
    assert_equal ['Unexpected error while requesting NLS', '#<RuntimeError: Big big error>'], found[:body]['errors']
  end

end
