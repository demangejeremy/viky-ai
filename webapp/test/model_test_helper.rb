def create_agent(name, user=:admin)
  agent = Agent.new(
    name: name,
    agentname: name.parameterize
  )
  agent.memberships << Membership.new(user_id: users(user).id, rights: 'all')
  assert agent.save
  agent
end


def force_reset_model_cache(models)
  if models.is_a? Array
    models.each(&:reload)
  else
    models.reload
  end
end


def create_agent_regression_check_fixtures
  @regression_weather_forecast = AgentRegressionCheck.new({
    sentence: "Quel temps fera-t-il demain ?",
    language: "*",
    now: "2019-01-21 12:00:00.000000",
    agent: agents(:weather),
    state: 0,
    position: 0,
    expected: {
      package: agents(:weather).id,
      id: intents(:weather_forecast).id,
      score: "1.0",
      solution: interpretations(:weather_forecast_tomorrow).solution.to_json.to_s
    }
  })
  @regression_weather_forecast.save!

  @regression_weather_question = AgentRegressionCheck.new({
    sentence: "What's the weather like in London ?",
    language: "en",
    now: "2019-01-20 14:00:15.000000",
    agent: agents(:weather),
    state: 2,
    position: 1,
    expected: {
      package: agents(:weather).id,
      id: intents(:weather_question).id,
      score: "0.65",
      solution: interpretations(:weather_question_like).solution.to_json.to_s
    }
  })
  @regression_weather_question.save!
end
