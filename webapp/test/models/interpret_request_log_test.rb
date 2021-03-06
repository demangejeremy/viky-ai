require 'test_helper'

class InterpretRequestLogTest < ActiveSupport::TestCase

  test 'Save a basic interpretation log' do
    weather_agent = agents(:weather)
    interpretation_weather = interpretations(:weather_question)
    log = InterpretRequestLog.new(
      timestamp: '2018-07-04T14:25:14.053+02:00',
      sentence: "What 's the weather like ?",
      language: 'en',
      spellchecking: 'low',
      agents: [weather_agent],
    ).with_response('200', {
      'interpretations' => [{
        'id' => interpretation_weather.id,
        'slug' => interpretation_weather.slug,
        'name' => interpretation_weather.interpretation_name,
        'score' => '0.83',
        'solution' => 'forecast.today'
      }]
    })
    assert log.save
    assert_equal 1, InterpretRequestLog.count
  end


  test 'Find an interpretation log by id' do
    weather_agent = agents(:weather)
    interpretation_weather = interpretations(:weather_question)
    log = InterpretRequestLog.new(
      timestamp: '2018-07-04T14:25:14+02:00',
      sentence: "What 's the weather like ?",
      language: 'en',
      spellchecking: 'low',
      now: '2018-07-10T14:10:36+02:00',
      agents: [weather_agent],
    ).with_response('200', {
      'interpretations' => [{
        'id' => interpretation_weather.id,
        'slug' => interpretation_weather.slug,
        'name' => interpretation_weather.interpretation_name,
        'score' => '0.83',
        'solution' => 'forecast.today'
      }]
    })
    assert log.save
    found = InterpretRequestLog.find(log.id)
    assert_equal log.timestamp, found.timestamp
    assert_equal log.sentence, found.sentence
    assert_equal log.language, found.language
    assert_equal log.spellchecking, found.spellchecking
    assert_equal log.now, found.now
    assert_equal log.status, found.status
    assert_equal log.body, found.body
  end


  test 'Count how much interpret request in a specific time frame' do
    weather_agent = agents(:weather)
    interpretation_weather_question = interpretations(:weather_question)
    interpretation_weather_forecast = interpretations(:weather_forecast)
    log = InterpretRequestLog.new(
      timestamp: '2018-07-04T08:00:00.200+02:00',
      sentence: 'What the weather like today ?',
      language: 'en',
      spellchecking: 'low',
      agents: [weather_agent],
    ).with_response('200', {
      'interpretations' => [{
        'id' => interpretation_weather_question.id,
        'slug' => interpretation_weather_question.slug,
        'name' => interpretation_weather_question.interpretation_name,
        'score' => '0.83',
        'solution' => 'forecast.today'
      }]
    })
    assert log.save
    log = InterpretRequestLog.new(
      timestamp: '2018-07-04T12:00:00.062+02:00',
      sentence: 'What the weather like tomorrow ?',
      language: 'en',
      spellchecking: 'low',
      agents: [weather_agent],
    ).with_response('200', {
      'interpretations' => [{
        'id' => interpretation_weather_forecast.id,
        'slug' => interpretation_weather_forecast.slug,
        'name' => interpretation_weather_forecast.interpretation_name,
        'score' => '0.83',
        'solution' => {
          'date' => 'tomorrow'
        }
      }]
    })
    assert log.save
    log = InterpretRequestLog.new(
      timestamp: '2018-07-04T16:00:00.000+02:00',
      sentence: 'What the weather like next Sunday ?',
      agents: [weather_agent],
    ).with_response('422', {
      errors: [
        "lt 0: OgNlsEndpoints : request error on endpoint : \"POST NlsEndpointInterpret\"",
        "NlpInterpretRequestBuildPackage: unknown package 'd4f359ed-fbe6-450b-a4c8-f449f232a699'"
      ]
    })
    assert log.save
    log = InterpretRequestLog.new(
      timestamp: '2018-07-04T17:00:00.000+02:00',
      sentence: 'What the weather like next Sunday ?',
      language: 'en',
      spellchecking: 'low',
      agents: [weather_agent],
    ).with_response('200', {})
    assert log.save
    assert_equal 2, InterpretRequestLog.count(
      query: {
        bool: {
          must_not: {
            term: { status: 422 }
          },
          must: {
            range: {
              timestamp: {
                gte: '2018-07-04T10:00:00+02:00',
                lte: '2018-07-04T18:00:00+02:00'
              }
            }
          }
        }
      }
    )
  end


  test 'Log an NLP response with an error message' do
    weather_agent = agents(:weather)
    log = InterpretRequestLog.new(
      timestamp: '2018-07-04T16:00:00.000+02:00',
      sentence: 'What the weather like next Sunday ?',
      agents: [weather_agent],
    ).with_response('401', {
      errors: ['Access denied: wrong token.']
    })
    assert log.save
  end


  test 'Log an interpretation with a context info' do
    log = InterpretRequestLog.new(
        timestamp: '2018-11-21T16:00:00.000+02:00',
        sentence: 'What the weather like today ?',
        agents: [agents(:weather)],
        context: {'client_type' => 'console', 'user_id' => '078602e7-0578-49d4-96ee-d8ee2f9b1ecf'}
      ).with_response('200', {
        interpretations: [{
          package: '132154f2-4545-4ae2-a802-3d39a2a5013f',
          id: 'a342f0ff-5d49-4a29-bc37-a9d754b99a7b',
          slug: 'viky/weather/interpretations/weather_question',
          score: '0.83',
          solution: {
            date: 'today'
          }
        }]
    })
    assert_not log.persisted?
    assert log.save
    assert log.persisted?
  end


  test 'Limit context size' do
    log = InterpretRequestLog.new(
      timestamp: '2018-11-21T16:00:00.000+02:00',
      sentence: 'What the weather like today ?',
      agents: [agents(:weather)],
      context: { 'foo' => 'bar' * 1000 }
    ).with_response('200', {
      interpretations: [{
        package: '132154f2-4545-4ae2-a802-3d39a2a5013f',
        id: 'a342f0ff-5d49-4a29-bc37-a9d754b99a7b',
        slug: 'viky/weather/interpretations/weather_question',
        score: '0.83',
        solution: {
          date: 'today'
        }
      }]
    })
    assert_not log.save
    assert_not log.persisted?
    expected = [:context_to_s, "is too long (maximum is 1000 characters)"]
    assert_equal expected, log.errors.first
  end

end
