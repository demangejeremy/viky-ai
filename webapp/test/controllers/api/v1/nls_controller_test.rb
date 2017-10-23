require 'test_helper'

class NlsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @fixtures_path = File.join(
      Rails.root, 'test', 'fixtures', 'controllers', 'api', 'v1', 'nls'
    )
  end


  test "Interpret route" do
    user_id  = 'admin'
    agent_id = 'weather'

    # Interpret action
    assert_routing({
      method: 'get',
      path: "api/v1/agents/#{user_id}/#{agent_id}/interpret"
    },
    {
      format: :json,
      controller: 'api/v1/nls',
      action: 'interpret',
      user_id: user_id,
      id: agent_id
    })
  end


  test "Agent access not permitted if token not good" do
    u = users(:admin)
    a = u.agents.first

    get "/api/v1/agents/#{u.username}/#{a.agentname}/interpret"
    assert_equal '401', response.code
    assert_equal "Wrong token for agent #{a.agentname}.", JSON.parse(response.body)["message"]

    get "/api/v1/agents/#{u.username}/#{a.agentname}/interpret",
      params: {agent_token: "blablabla"}
    assert_equal '401', response.code
    assert_equal "Wrong token for agent #{a.agentname}.", JSON.parse(response.body)["message"]
  end


  test "Agent token can be specified in the request header and in the request parameters" do
    nls_layer_interpret_200 = JSON.parse(File.read(File.join(@fixtures_path, "nls_layer_interpret_200.json")))
    nls_interpret_200 = JSON.parse(File.read(File.join(@fixtures_path, "nls_interpret_200.json")))
    Nls::Interpret.any_instance.stubs('post_to_nls').returns(nls_layer_interpret_200)

    u = users(:admin)
    a = u.agents.first

    get "/api/v1/agents/#{u.username}/#{a.agentname}/interpret",
      params: {sentence: "test", agent_token: a.api_token}
    assert response.code == '200'
    assert_equal nls_interpret_200, JSON.parse(response.body)

    get "/api/v1/agents/#{u.username}/#{a.agentname}/interpret",
      params: {sentence: "test"},
      headers: {"Agent-Token" => a.api_token}
    assert response.code == '200'
    assert_equal nls_interpret_200, JSON.parse(response.body)
  end


  test "Agent token in the request header overloads agent token in the request parameters" do
    nls_layer_interpret_200 = JSON.parse(File.read(File.join(@fixtures_path, "nls_layer_interpret_200.json")))
    Nls::Interpret.any_instance.stubs('post_to_nls').returns(nls_layer_interpret_200)

    u = users(:admin)
    a = u.agents.first
    wrong_token = "blablabla"

    get "/api/v1/agents/#{u.username}/#{a.agentname}/interpret",
      params: {sentence: "test", agent_token: wrong_token}
    assert response.code == '401'

    get "/api/v1/agents/#{u.username}/#{a.agentname}/interpret",
      params: {sentence: "test", agent_token: wrong_token},
      headers: {"Agent-Token" => a.api_token}
    assert response.code == '200'
  end


  test "An empty sentence request is unprocessable" do
    u = users(:admin)
    a = u.agents.first

    get "/api/v1/agents/#{u.username}/#{a.agentname}/interpret?agent_token=#{a.api_token}"
    assert_equal '422', response.code
    assert_equal ["is empty"], JSON.parse(response.body)["message"]["sentence"]
  end

end
