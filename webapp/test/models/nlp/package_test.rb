require 'test_helper'

class PackageTest < ActiveSupport::TestCase

  test "package generation" do
    weather = agents(:weather)
    p = Nlp::Package.new(weather)

    expected = {
      "id"   => weather.id,
      "slug" => "admin/weather",
      "interpretations" => [
        {
          "id"    => interpretations(:weather_forecast).id,
          "slug"  => "admin/weather/interpretations/weather_forecast",
          'scope' => 'public',
          "expressions" => [
            {
              "expression"    => "Quel temps fera-t-il demain ?",
              "pos"            => formulations(:weather_forecast_demain).position,
              "locale"        => "fr",
              "glue-distance" => 20,
              "solution"      => "Quel temps fera-t-il demain ?",
            },
            {
              "expression" => "@{question} @{when} ?",
              "pos"         => formulations(:weather_forecast_tomorrow).position,
              "aliases"    => [
                {
                  "alias"   => "question",
                  "slug"    => "admin/weather/interpretations/weather_question",
                  "id"      => interpretations(:weather_question).id,
                  "package" => weather.id
                },
                {
                  "alias"   => "when",
                  "slug"    => "admin/weather/entities_lists/weather_dates",
                  "id"      => entities_lists(:weather_dates).id,
                  "package" => weather.id
                }
              ],
              "locale"         => "en",
              "keep-order"     => true,
              "glue-distance" => 0,
              "solution"       => "`forecast.tomorrow`"
            }
          ]
        },
        {
          "id"    => interpretations(:weather_question).id,
          "slug"  => "admin/weather/interpretations/weather_question",
          'scope' => 'public',
          "expressions" => [
            {
              "expression"    => "What the weather like",
              "pos"            => formulations(:weather_question_like).position,
              "locale"        => "en",
              "glue-distance" => 20,
              "solution"      => "What the weather like",
            }
          ]
        },
        {
          "id"       => entities_lists(:weather_conditions).id,
          "slug"     => "admin/weather/entities_lists/weather_conditions",
          'scope'    => 'public',
          "expressions" => [
            {
              "expression" => "sun",
              "pos"         => entities(:weather_sunny).position,
              "locale"     => "en",
              "keep-order" => true,
              "glue-distance" => 0,
              "glue-strength" => "punctuation",
              "solution"   => "sun",
            },
            {
              "expression" => "soleil",
              "pos"         => entities(:weather_sunny).position,
              "locale"     => "fr",
              "keep-order" => true,
              "glue-distance" => 0,
              "glue-strength" => "punctuation",
              "solution"   => "sun",
            },
            {
              "expression"    => "pluie",
              "pos"            => entities(:weather_raining).position,
              "locale"        => "fr",
              "keep-order"    => true,
              "glue-distance" => 0,
              "glue-strength" => "punctuation",
              "solution"      => "pluie",
            },
            {
              "expression" => "rain",
              "pos"         => entities(:weather_raining).position,
              "locale"     => "en",
              "keep-order" => true,
              "glue-distance" => 0,
              "glue-strength" => "punctuation",
              "solution"   => "pluie",
            }
          ]
        },
        {
          "id"       => entities_lists(:weather_dates).id,
          "slug"     => "admin/weather/entities_lists/weather_dates",
          'scope'    => 'public',
          "expressions" => [
            {
              "expression" => "aujourd'hui",
              "pos"         => entities(:weather_dates_today).position,
              "locale"     => "fr",
              "keep-order" => true,
              "glue-distance" => 0,
              "glue-strength" => "punctuation",
              "solution"   => "`{\"date\": \"today\"}`",
            },
            {
              "expression" => "tout à l'heure",
              "pos"         => entities(:weather_dates_today).position,
              "locale"     => "fr",
              "keep-order" => true,
              "glue-distance" => 0,
              "glue-strength" => "punctuation",
              "solution"   => "`{\"date\": \"today\"}`",
            },
            {
              "expression" => "today",
              "pos"         => entities(:weather_dates_today).position,
              "locale"     => "en",
              "keep-order" => true,
              "glue-distance" => 0,
              "glue-strength" => "punctuation",
              "solution"   => "`{\"date\": \"today\"}`",
            },
            {
              "expression" => "tomorrow",
              "pos"         => entities(:weather_dates_tomorrow).position,
              "keep-order" => true,
              "glue-distance" => 0,
              "glue-strength" => "punctuation",
              "solution"   => "`{\"date\": \"tomorrow\"}`",
            }
          ]
        }
      ]
    }
    io = StringIO.new
    p.generate_json(io)
    assert_equal expected, JSON.parse(io.string)
  end


  test 'Package generation with locale any' do
    weather = agents(:weather)
    interpretation = interpretations(:weather_forecast)
    formulation = formulations(:weather_forecast_demain)
    formulation.locale = Locales::ANY
    formulation.save
    assert entities_lists(:weather_conditions).destroy
    assert entities_lists(:weather_dates).destroy
    interpretation.formulations = [formulation]
    interpretation.save
    assert interpretations(:weather_question).destroy

    p = Nlp::Package.new(weather)

    expected = {
      "id"   => weather.id,
      "slug" => "admin/weather",
      "interpretations" => [
        {
          "id"    => interpretation.id,
          "slug"  => "admin/weather/interpretations/weather_forecast",
          'scope' => 'public',
          "expressions" => [
            {
              "expression"    => "Quel temps fera-t-il demain ?",
              "pos"            => formulations(:weather_forecast_demain).position,
              "solution"      => "Quel temps fera-t-il demain ?",
              "glue-distance" => 20
            }
          ]
        }
      ]
    }
    io = StringIO.new
    p.generate_json(io)
    assert_equal expected, JSON.parse(io.string)
  end


  test 'Package generation with private interpretation' do
    weather = agents(:weather)
    interpretation = interpretations(:weather_question)
    interpretation.visibility = Interpretation.visibilities[:is_private]
    interpretation.save
    assert entities_lists(:weather_conditions).destroy
    assert entities_lists(:weather_dates).destroy
    assert interpretations(:weather_forecast).destroy

    p = Nlp::Package.new(weather)

    expected = {
      "id"   => weather.id,
      "slug" => "admin/weather",
      "interpretations" => [
        {
          "id"    => interpretations(:weather_question).id,
          "slug"  => "admin/weather/interpretations/weather_question",
          'scope' => 'private',
          "expressions" => [
            {
              "expression"    => "What the weather like",
              "pos"            => formulations(:weather_question_like).position,
              "locale"        => "en",
              "solution"      => "What the weather like",
              "glue-distance" => 20
            }
          ]
        }
      ]
    }
    io = StringIO.new
    p.generate_json(io)
    assert_equal expected, JSON.parse(io.string)
  end


  test 'Package generation with alias list' do
    weather = agents(:weather)
    ialias = formulation_aliases(:weather_forecast_tomorrow_question)
    ialias.is_list = true
    assert entities_lists(:weather_conditions).destroy
    assert entities_lists(:weather_dates).destroy
    assert ialias.save

    p = Nlp::Package.new(weather)

    expected = {
      "id"   => weather.id,
      "slug" => "admin/weather",
      "interpretations" => [
        {
          "id"          => "#{interpretations(:weather_question).id}_#{ialias.id}_recursive",
          "slug"        => "admin/weather/interpretations/weather_question_#{ialias.id}_recursive",
          "scope"       => "hidden",
          "expressions" => [
            {
              "expression" => "@{question}",
              "pos"         => formulations(:weather_forecast_tomorrow).position,
              "aliases"    => [
                {
                  "alias"   => "question",
                  "slug"    => "admin/weather/interpretations/weather_question",
                  "id"      => interpretations(:weather_question).id,
                  "package" => weather.id
                }
              ],
              "keep-order"    => true,
              "glue-distance" => 0
            },
            {
              "expression" => "@{question} @{question_recursive}",
              "pos"         => formulations(:weather_forecast_tomorrow).position,
              "aliases"    => [
                {
                  "alias"   => "question",
                  "slug"    => "admin/weather/interpretations/weather_question",
                  "id"      => interpretations(:weather_question).id,
                  "package" => weather.id
                },
                {
                  "alias"   => "question_recursive",
                  "slug"    => "admin/weather/interpretations/weather_question_#{ialias.id}_recursive",
                  "id"      => "#{interpretations(:weather_question).id}_#{ialias.id}_recursive",
                  "package" => weather.id
                }
              ],
              "keep-order"    => true,
              "glue-distance" => 0
            }
          ]
        },
        {
          "id"    => interpretations(:weather_forecast).id,
          "slug"  => "admin/weather/interpretations/weather_forecast",
          'scope' => 'public',
          "expressions" => [
            {
              "expression"     => "Quel temps fera-t-il demain ?",
              "pos"             => formulations(:weather_forecast_demain).position,
              "locale"         => "fr",
              "solution"       => "Quel temps fera-t-il demain ?",
              "glue-distance"  => 20
            },
            {
              "expression" => "@{question} tomorrow ?",
              "pos"         => formulations(:weather_forecast_tomorrow).position,
              "aliases"    => [
                {
                  "alias"   => "question",
                  "slug"    => "admin/weather/interpretations/weather_question_#{ialias.id}_recursive",
                  "id"      => "#{interpretations(:weather_question).id}_#{ialias.id}_recursive",
                  "package" => weather.id
                }
              ],
              "locale"        => "en",
              "keep-order"    => true,
              "glue-distance" => 0,
              "solution"      => "`forecast.tomorrow`"
            }
          ]
        },
        {
          "id"    => interpretations(:weather_question).id,
          "slug"  => "admin/weather/interpretations/weather_question",
          'scope' => 'public',
          "expressions" => [
            {
              "expression"    => "What the weather like",
              "pos"            => formulations(:weather_question_like).position,
              "locale"        => "en",
              "solution"      => "What the weather like",
              "glue-distance" => 20
            }
          ]
        }
      ]
    }
    io = StringIO.new
    p.generate_json(io)
    assert_equal expected, JSON.parse(io.string)
  end

  test 'Package generation with alias any' do
    weather = agents(:weather)
    assert entities_lists(:weather_conditions).destroy
    assert entities_lists(:weather_dates).destroy
    ialias = formulation_aliases(:weather_forecast_tomorrow_question)
    ialias.any_enabled = true
    assert ialias.save

    p = Nlp::Package.new(weather)

    expected = {
      'id'   => weather.id,
      'slug' => 'admin/weather',
      'interpretations' => [
        {
          'id'    => interpretations(:weather_forecast).id,
          'slug'  => 'admin/weather/interpretations/weather_forecast',
          'scope' => 'public',
          'expressions' => [
            {
              'expression'    => 'Quel temps fera-t-il demain ?',
              'pos'           => formulations(:weather_forecast_demain).position,
              'locale'        => 'fr',
              'solution'      => 'Quel temps fera-t-il demain ?',
              "glue-distance" => 20
            },
            {
              'expression' => '@{question} tomorrow ?',
              'pos'        => formulations(:weather_forecast_tomorrow).position,
              'aliases'    => [
                {
                  'alias'   => 'question',
                  'slug'    => 'admin/weather/interpretations/weather_question',
                  'id'      => interpretations(:weather_question).id,
                  'package' => weather.id
                }
              ],
              'locale'        => 'en',
              'keep-order'    => true,
              'glue-distance' => 0,
              'solution'      => '`forecast.tomorrow`'
            },
            {
              'expression' => '@{question} tomorrow ?',
              'pos'        => formulations(:weather_forecast_tomorrow).position,
              'aliases'    => [
                {
                  'alias'   => 'question',
                  'type'    => 'any'
                }
              ],
              'locale'        => 'en',
              'keep-order'    => true,
              'glue-distance' => 0,
              'solution'      => '`forecast.tomorrow`'
            }
          ]
        },
        {
          'id'    => interpretations(:weather_question).id,
          'slug'  => 'admin/weather/interpretations/weather_question',
          'scope' => 'public',
          'expressions' => [
            {
              'expression'    => 'What the weather like',
              'pos'           => formulations(:weather_question_like).position,
              'locale'        => 'en',
              'solution'      => "What the weather like",
              "glue-distance" => 20
            }
          ]
        }
      ]
    }
    io = StringIO.new
    p.generate_json(io)
    assert_equal expected, JSON.parse(io.string)
  end


  test 'Packages with all its dependencies' do
    weather = agents(:weather)
    terminator = agents(:terminator)
    assert AgentArc.create(source: weather, target: terminator)
    assert entities_lists(:weather_conditions).destroy
    assert entities_lists(:weather_dates).destroy
    weather.reload
    p = Nlp::Package.new(weather)

    expected = [{
      "id"   => weather.id,
      "slug" => "admin/weather",
      "interpretations" => [
        {
          "id"          => interpretations(:weather_forecast).id,
          "slug"        => "admin/weather/interpretations/weather_forecast",
          'scope'       => 'public',
          "expressions" => [
            {
              "expression"    => "Quel temps fera-t-il demain ?",
              "pos"           => formulations(:weather_forecast_demain).position,
              "locale"        => "fr",
              "solution"      => "Quel temps fera-t-il demain ?",
              "glue-distance" => 20
            },
            {
              "expression" => "@{question} tomorrow ?",
              "pos"        => formulations(:weather_forecast_tomorrow).position,
              "aliases"    => [
                {
                  "alias"   => "question",
                  "slug"    => "admin/weather/interpretations/weather_question",
                  "id"      => interpretations(:weather_question).id,
                  "package" => weather.id
                }
              ],
              "locale"        => "en",
              "keep-order"    => true,
              "glue-distance" => 0,
              "solution"      => "`forecast.tomorrow`"
            }
          ]
        },
        {
          "id"    => interpretations(:weather_question).id,
          "slug"  => "admin/weather/interpretations/weather_question",
          'scope' => 'public',
          "expressions" => [
            {
              "expression"    => "What the weather like",
              "pos"           => formulations(:weather_question_like).position,
              "locale"        => "en",
              "solution"      => "What the weather like",
              "glue-distance" => 20
            }
          ]
        }
      ]
    }, {
      "id"   => terminator.id,
      "slug" => "admin/terminator",
      "interpretations" => [
        {
          "id"    => interpretations(:simple_where).id,
          "slug"  => "admin/terminator/interpretations/simple_where",
          "scope" => "private",
          "expressions"=>  [
              {
                "expression"    => "Find",
                "pos"           => formulations(:terminator_simple_where_1).position,
                "locale"        => "en",
                "solution"      => "Find",
                "glue-distance" => 20
              }
            ]
        },
        {
          "id"    => interpretations(:terminator_find).id,
          "slug"  => "admin/terminator/interpretations/terminator_find",
          "scope" => "public",
          "expressions" => [
            {
              "expression" => "@{find} Sarah Connor",
              "pos"        => formulations(:terminator_where).position,
              "aliases"=> [
                {
                  "alias"   => "find",
                  "slug"    => "admin/terminator/interpretations/simple_where",
                  "id"      => interpretations(:simple_where).id,
                  "package" => terminator.id
                }
              ],
              "locale"        =>"en",
              "glue-distance" => 20
            },
            {
              "expression"    => "Where is Sarah Connor ?",
              "pos"            => formulations(:terminator_find_sarah).position,
              "locale"        => "en",
              "solution"      => "Where is Sarah Connor ?",
              "glue-distance" => 20
            }
          ]
        },
        {
          "id"    => entities_lists(:terminator_targets).id,
          "slug"  => "admin/terminator/entities_lists/terminator_targets",
          "scope" => "private",
          "expressions" => []
        }]
    }]

    io = StringIO.new
    p.full_json_export(io)
    assert_equal expected, JSON.parse(io.string)
  end


  test 'No formulation alias' do
    expected_expression = 'I want to go to Paris from London'
    formulation = Formulation.new(expression: 'I want to go to Paris from London', locale: 'en')
    formulation.save
    assert_equal expected_expression, formulation.expression_with_aliases
  end


  test 'Only formulation alias' do
    expected_expression = '@{route}'

    formulation = Formulation.new
    formulation_alias = FormulationAlias.new

    formulation_alias.stubs(:position_start).returns(0)
    formulation_alias.stubs(:position_end).returns(33)
    formulation_alias.stubs(:formulation).returns(formulation)
    formulation_alias.stubs(:aliasname).returns('route')

    formulation.stubs(:expression).returns('I want to go to Paris from London')
    array = [formulation_alias]
    array.stubs(:order).returns([formulation_alias])
    array.stubs(:count).returns([formulation_alias].size)
    formulation.stubs(:formulation_aliases).returns(array)

    assert_equal expected_expression, formulation.expression_with_aliases
  end


  test 'Start with formulation alias' do
    expected_expression = '@{want} to go to Paris from London'

    formulation = Formulation.new
    formulation_alias = FormulationAlias.new

    formulation_alias.stubs(:position_start).returns(0)
    formulation_alias.stubs(:position_end).returns(6)
    formulation_alias.stubs(:formulation).returns(formulation)
    formulation_alias.stubs(:aliasname).returns('want')

    formulation.stubs(:expression).returns('I want to go to Paris from London')
    array = [formulation_alias]
    array.stubs(:order).returns([formulation_alias])
    array.stubs(:count).returns([formulation_alias].size)
    formulation.stubs(:formulation_aliases).returns(array)

    assert_equal expected_expression, formulation.expression_with_aliases
  end


  test 'End with formulation alias' do
    expected_expression = 'I want to go to Paris from @{london}'

    formulation = Formulation.new
    formulation_alias = FormulationAlias.new

    formulation_alias.stubs(:position_start).returns(27)
    formulation_alias.stubs(:position_end).returns(33)
    formulation_alias.stubs(:formulation).returns(formulation)
    formulation_alias.stubs(:aliasname).returns('london')

    formulation.stubs(:expression).returns('I want to go to Paris from London')
    array = [formulation_alias]
    array.stubs(:order).returns([formulation_alias])
    array.stubs(:count).returns([formulation_alias].size)
    formulation.stubs(:formulation_aliases).returns(array)

    assert_equal expected_expression, formulation.expression_with_aliases
  end


  test 'Middle formulation alias' do
    expected_expression = 'I want to go @{prep-to} Paris from London'

    formulation = Formulation.new
    formulation_alias = FormulationAlias.new

    formulation_alias.stubs(:position_start).returns(13)
    formulation_alias.stubs(:position_end).returns(15)
    formulation_alias.stubs(:formulation).returns(formulation)
    formulation_alias.stubs(:aliasname).returns('prep-to')

    formulation.stubs(:expression).returns('I want to go to Paris from London')
    array = [formulation_alias]
    array.stubs(:order).returns([formulation_alias])
    array.stubs(:count).returns([formulation_alias].size)
    formulation.stubs(:formulation_aliases).returns(array)

    assert_equal expected_expression, formulation.expression_with_aliases
  end


  test 'Repeated formulation alias' do
    expected_expression = 'I want to go to @{town_from} from @{town_to}'

    formulation = Formulation.new
    formulation_alias1 = FormulationAlias.new
    formulation_alias2 = FormulationAlias.new

    formulation_alias1.stubs(:position_start).returns(16)
    formulation_alias1.stubs(:position_end).returns(21)
    formulation_alias1.stubs(:formulation).returns(formulation)
    formulation_alias1.stubs(:aliasname).returns('town_from')

    formulation_alias2.stubs(:position_start).returns(27)
    formulation_alias2.stubs(:position_end).returns(33)
    formulation_alias2.stubs(:formulation).returns(formulation)
    formulation_alias2.stubs(:aliasname).returns('town_to')

    formulation.stubs(:expression).returns('I want to go to Paris from London')
    array = [formulation_alias1, formulation_alias2]
    array.stubs(:order).returns([formulation_alias1, formulation_alias2])
    array.stubs(:count).returns([formulation_alias1, formulation_alias2].size)
    formulation.stubs(:formulation_aliases).returns(array)

    assert_equal expected_expression, formulation.expression_with_aliases
  end


  test 'Package generation with regex type' do
    agent = agents(:terminator)
    formulation = formulations(:terminator_find_sarah)
    assert entities_lists(:terminator_targets).destroy
    assert formulations(:terminator_where).destroy
    assert interpretations(:simple_where).destroy

    regex_alias = FormulationAlias.new(
      position_start: 9,
      position_end: 21,
      aliasname: 'name',
      formulation_id: formulation.id,
      nature: 'type_regex',
      reg_exp: '[A-Za-z,-]'
    )
    assert regex_alias.save

    package = Nlp::Package.new(agent)
    expected = {
      "id"   => agent.id,
      "slug" => "admin/terminator",
      "interpretations" => [
        {
          "id"    => formulation.interpretation.id,
          "slug"  => "admin/terminator/interpretations/terminator_find",
          'scope' => 'public',
          "expressions" => [
            {
              "expression" => "Where is @{name} ?",
              "pos"        => formulations(:terminator_find_sarah).position,
              "aliases"    => [
                {
                  "alias"   => "name",
                  "type"    => "regex",
                  "regex"   => "[A-Za-z,-]"
                }
              ],
              "locale"        => "en",
              "glue-distance" => 20
            }
          ]
        }
      ]
    }
    io = StringIO.new
    package.generate_json(io)
    assert_equal expected, JSON.parse(io.string)
  end

  test 'Package generation with different proximity values' do
    weather = agents(:weather)
    formulation_far = formulations(:weather_forecast_demain)
    formulation_far.proximity = 'accepts_punctuations'
    assert formulation_far.save

    formulation_very_close = formulations(:weather_question_like)
    formulation_very_close.proximity = 'very_close'
    assert formulation_very_close.save

    entities_far = entities_lists(:weather_dates)
    entities_far.proximity = 'far'
    assert entities_far.save

    assert formulations(:weather_forecast_tomorrow).destroy
    p = Nlp::Package.new(weather)

    expected = {
      "id"   => weather.id,
      "slug" => "admin/weather",
      "interpretations" => [
        {
          "id"    => interpretations(:weather_forecast).id,
          "slug"  => "admin/weather/interpretations/weather_forecast",
          'scope' => 'public',
          "expressions" => [
            {
              "expression"    => "Quel temps fera-t-il demain ?",
              "pos"           => formulations(:weather_forecast_demain).position,
              "locale"        => "fr",
              "glue-distance" => 0,
              "glue-strength" => 'punctuation',
              "solution"      => "Quel temps fera-t-il demain ?",
            }
          ]
        },
        {
          "id"    => interpretations(:weather_question).id,
          "slug"  => "admin/weather/interpretations/weather_question",
          'scope' => 'public',
          "expressions" => [
            {
              "expression"    => "What the weather like",
              "pos"           => formulations(:weather_question_like).position,
              "locale"        => "en",
              "solution"      => "What the weather like",
              "glue-distance" => 10
            }
          ]
        },
        {
          "id"       => entities_lists(:weather_conditions).id,
          "slug"     => "admin/weather/entities_lists/weather_conditions",
          'scope'    => 'public',
          "expressions" => [
            {
              "expression"    => "sun",
              "pos"           => entities(:weather_sunny).position,
              "locale"        => "en",
              "keep-order"    => true,
              "glue-distance" => 0,
              "glue-strength" => "punctuation",
              "solution"      => "sun",
            },
            {
              "expression"    => "soleil",
              "pos"           => entities(:weather_sunny).position,
              "locale"        => "fr",
              "keep-order"    => true,
              "glue-distance" => 0,
              "glue-strength" => "punctuation",
              "solution"      => "sun",
            },
            {
              "expression"    => "pluie",
              "pos"           => entities(:weather_raining).position,
              "locale"        => "fr",
              "keep-order"    => true,
              "glue-distance" => 0,
              "glue-strength" => "punctuation",
              "solution"      => "pluie",
            },
            {
              "expression"    => "rain",
              "pos"           => entities(:weather_raining).position,
              "locale"        => "en",
              "keep-order"    => true,
              "glue-distance" => 0,
              "glue-strength" => "punctuation",
              "solution"      => "pluie",
            }
          ]
        },
        {
          "id"       => entities_lists(:weather_dates).id,
          "slug"     => "admin/weather/entities_lists/weather_dates",
          'scope'    => 'public',
          "expressions" => [
            {
              "expression"    => "aujourd'hui",
              "pos"           => entities(:weather_dates_today).position,
              "locale"        => "fr",
              "keep-order"    => true,
              "glue-distance" => 50,
              "solution"      => "`{\"date\": \"today\"}`",
            },
            {
              "expression"    => "tout à l'heure",
              "pos"           => entities(:weather_dates_today).position,
              "locale"        => "fr",
              "keep-order"    => true,
              "glue-distance" => 50,
              "solution"      => "`{\"date\": \"today\"}`",
            },
            {
              "expression"    => "today",
              "pos"           => entities(:weather_dates_today).position,
              "locale"        => "en",
              "keep-order"    => true,
              "glue-distance" => 50,
              "solution"      => "`{\"date\": \"today\"}`",
            },
            {
              "expression"    => "tomorrow",
              "pos"           => entities(:weather_dates_tomorrow).position,
              "keep-order"    => true,
              "glue-distance" => 50,
              "solution"      => "`{\"date\": \"tomorrow\"}`",
            }
          ]
        }
      ]
    }
    io = StringIO.new
    p.generate_json(io)
    assert_equal expected, JSON.parse(io.string)
  end


  test "Package generation with cache" do
    weather = agents(:weather)
    cache = ActiveSupport::Cache::MemoryStore.new
    p = Nlp::Package.new(weather, cache)

    expected = {
      "id"   => weather.id,
      "slug" => "admin/weather",
      "interpretations" => [
        {
          "id"    => interpretations(:weather_forecast).id,
          "slug"  => "admin/weather/interpretations/weather_forecast",
          'scope' => 'public',
          "expressions" => [
            {
              "expression"    => "Quel temps fera-t-il demain ?",
              "pos"           => 1,
              "locale"        => "fr",
              "glue-distance" => 20,
              "solution"      => "Quel temps fera-t-il demain ?",
            },
            {
              "expression" => "@{question} @{when} ?",
              "pos"        => 0,
              "aliases"    => [
                {
                  "alias"   => "question",
                  "slug"    => "admin/weather/interpretations/weather_question",
                  "id"      => interpretations(:weather_question).id,
                  "package" => weather.id
                },
                {
                  "alias"   => "when",
                  "slug"    => "admin/weather/entities_lists/weather_dates",
                  "id"      => entities_lists(:weather_dates).id,
                  "package" => weather.id
                }
              ],
              "locale"         => "en",
              "keep-order"     => true,
              "glue-distance" => 0,
              "solution"       => "`forecast.tomorrow`"
            }
          ]
        },
        {
          "id"    => interpretations(:weather_question).id,
          "slug"  => "admin/weather/interpretations/weather_question",
          'scope' => 'public',
          "expressions" => [
            {
              "expression"    => "What the weather like",
              "pos"           => 0,
              "locale"        => "en",
              "glue-distance" => 20,
              "solution"      => "What the weather like",
            }
          ]
        },
        {
          "id"       => entities_lists(:weather_conditions).id,
          "slug"     => "admin/weather/entities_lists/weather_conditions",
          'scope'    => 'public',
          "expressions" => [
            {
              "expression" => "sun",
              "pos"        => 1,
              "locale"     => "en",
              "keep-order" => true,
              "glue-distance" => 0,
              "glue-strength" => "punctuation",
              "solution"   => "sun",
            },
            {
              "expression" => "soleil",
              "pos"        => 1,
              "locale"     => "fr",
              "keep-order" => true,
              "glue-distance" => 0,
              "glue-strength" => "punctuation",
              "solution"   => "sun",
            },
            {
              "expression"    => "pluie",
              "pos"           => 0,
              "locale"        => "fr",
              "keep-order"    => true,
              "glue-distance" => 0,
              "glue-strength" => "punctuation",
              "solution"      => "pluie",
            },
            {
              "expression" => "rain",
              "pos"        => 0,
              "locale"     => "en",
              "keep-order" => true,
              "glue-distance" => 0,
              "glue-strength" => "punctuation",
              "solution"   => "pluie",
            }
          ]
        },
        {
          "id"       => entities_lists(:weather_dates).id,
          "slug"     => "admin/weather/entities_lists/weather_dates",
          'scope'    => 'public',
          "expressions" => [
            {
              "expression" => "aujourd'hui",
              "pos"        => 1,
              "locale"     => "fr",
              "keep-order" => true,
              "glue-distance" => 0,
              "glue-strength" => "punctuation",
              "solution"   => "`{\"date\": \"today\"}`",
            },
            {
              "expression" => "tout à l'heure",
              "pos"        => 1,
              "locale"     => "fr",
              "keep-order" => true,
              "glue-distance" => 0,
              "glue-strength" => "punctuation",
              "solution"   => "`{\"date\": \"today\"}`",
            },
            {
              "expression" => "today",
              "pos"        => 1,
              "locale"     => "en",
              "keep-order" => true,
              "glue-distance" => 0,
              "glue-strength" => "punctuation",
              "solution"   => "`{\"date\": \"today\"}`",
            },
            {
              "expression" => "tomorrow",
              "pos"        => 0,
              "keep-order" => true,
              "glue-distance" => 0,
              "glue-strength" => "punctuation",
              "solution"   => "`{\"date\": \"tomorrow\"}`",
            }
          ]
        }
      ]
    }
    io = StringIO.new
    p.generate_json(io) # First run to fill the cache
    other_io = StringIO.new
    p.generate_json(other_io) # Use the cache
    assert_equal expected, JSON.parse(other_io.string)
  end


  test 'Detect stale cache' do
    weather = agents(:weather)
    cache = ActiveSupport::Cache::MemoryStore.new
    p = Nlp::Package.new(weather, cache)

    expected = {
      "id"   => weather.id,
      "slug" => "admin/weather",
      "interpretations" => [
        {
          "id"    => interpretations(:weather_forecast).id,
          "slug"  => "admin/weather/interpretations/weather_forecast",
          'scope' => 'public',
          "expressions" => [
            {
              "expression" => "@{question} @{when} ?",
              "pos"        => 2,
              "aliases"    => [
                {
                  "alias"   => "question",
                  "slug"    => "admin/weather/interpretations/weather_question",
                  "id"      => interpretations(:weather_question).id,
                  "package" => weather.id
                },
                {
                  "alias"   => "when",
                  "slug"    => "admin/weather/entities_lists/weather_dates",
                  "id"      => entities_lists(:weather_dates).id,
                  "package" => weather.id
                }
              ],
              "locale"         => "en",
              "keep-order"     => true,
              "glue-distance" => 0,
              "solution"       => "`forecast.tomorrow`"
            },
            {
              "expression"    => "Quel temps fera-t-il demain ?",
              "pos"           => 1,
              "locale"        => "fr",
              "glue-distance" => 20,
              "solution"      => "Quel temps fera-t-il demain ?",
            }
          ]
        },
        {
          "id"    => interpretations(:weather_question).id,
          "slug"  => "admin/weather/interpretations/weather_question",
          'scope' => 'public',
          "expressions" => [
            {
              "expression"    => "What the weather like",
              "pos"           => 0,
              "locale"        => "en",
              "glue-distance" => 20,
              "solution"      => "What the weather like",
            }
          ]
        },
        {
          "id"       => entities_lists(:weather_conditions).id,
          "slug"     => "admin/weather/entities_lists/weather_conditions",
          'scope'    => 'public',
          "expressions" => [
            {
              "expression"    => "pluie",
              "pos"           => 2,
              "locale"        => "fr",
              "keep-order"    => true,
              "glue-distance" => 0,
              "glue-strength" => "punctuation",
              "solution"      => "pluie",
            },
            {
              "expression" => "rain",
              "pos"        => 2,
              "locale"     => "en",
              "keep-order" => true,
              "glue-distance" => 0,
              "glue-strength" => "punctuation",
              "solution"   => "pluie",
            },
            {
              "expression" => "sun",
              "pos"        => 1,
              "locale"     => "en",
              "keep-order" => true,
              "glue-distance" => 0,
              "glue-strength" => "punctuation",
              "solution"   => "sun",
            },
            {
              "expression" => "soleil",
              "pos"        => 1,
              "locale"     => "fr",
              "keep-order" => true,
              "glue-distance" => 0,
              "glue-strength" => "punctuation",
              "solution"   => "sun",
            }
          ]
        },
        {
          "id"       => entities_lists(:weather_dates).id,
          "slug"     => "admin/weather/entities_lists/weather_dates",
          'scope'    => 'public',
          "expressions" => [
            {
              "expression" => "tomorrow",
              "pos"        => 2,
              "keep-order" => true,
              "glue-distance" => 0,
              "glue-strength" => "punctuation",
              "solution"   => "`{\"date\": \"tomorrow\"}`",
            },
            {
              "expression" => "aujourd'hui",
              "pos"        => 1,
              "locale"     => "fr",
              "keep-order" => true,
              "glue-distance" => 0,
              "glue-strength" => "punctuation",
              "solution"   => "`{\"date\": \"today\"}`",
            },
            {
              "expression" => "tout à l'heure",
              "pos"        => 1,
              "locale"     => "fr",
              "keep-order" => true,
              "glue-distance" => 0,
              "glue-strength" => "punctuation",
              "solution"   => "`{\"date\": \"today\"}`",
            },
            {
              "expression" => "today",
              "pos"        => 1,
              "locale"     => "en",
              "keep-order" => true,
              "glue-distance" => 0,
              "glue-strength" => "punctuation",
              "solution"   => "`{\"date\": \"today\"}`",
            }
          ]
        }
      ]
    }


    io = StringIO.new
    p.generate_json(io) # First run to fill the cache
    other_io = StringIO.new

    # Create stale cache by changing data in the DB
    formulation = formulations(:weather_forecast_tomorrow)
    formulation.position = 2
    assert formulation.save!
    entity = entities(:weather_raining)
    entity.position = 2
    assert entity.save!
    entity = entities(:weather_dates_tomorrow)
    entity.position = 2
    assert entity.save!

    p.generate_json(other_io) # Use the cache
    assert_equal expected, JSON.parse(other_io.string)
  end

  test 'Package generation with case_sensitive and accent_sensitive' do
    cities = agents(:cities)
    p = Nlp::Package.new(cities)

    expected = {
      "id"=>"30d3b81b-52f4-5fb3-a6f7-b2f025dece97",
      "slug"=>"locked/cities",
      "interpretations"=> [
        {
          "id"=>"30d3b81b-52f4-5fb3-a6f7-b2f025dece97",
          "slug"=>"locked/cities/entities_lists/cities",
          "scope"=>"private",
          "expressions"=> [
            {
              "expression"=>"Mâcon",
              "pos"=>3,
              "solution"=>"`{\"city\": \"Mâcon\"}`",
              "keep-order"=>true,
              "glue-distance"=>0,
              "glue-strength"=>"punctuation",
              "accent-sensitive"=>true},

            {
              "expression"=>"Orléans",
              "pos"=>2,
              "solution"=>"`{\"city\": \"Orléans\"}`",
              "keep-order"=>true,
              "glue-distance"=>0,
              "glue-strength"=>"punctuation",
              "case-sensitive"=>true,
              "accent-sensitive"=>true
            },
            {
              "expression"=>"Marseille",
              "pos"=>1,
              "solution"=>"`{\"city\": \"Marseille\"}`",
              "keep-order"=>true,
              "glue-distance"=>0,
              "glue-strength"=>"punctuation"
            },
            {
              "expression"=>"Paris",
              "pos"=>0,
              "solution"=>"`{\"city\": \"Paris\"}`",
              "keep-order"=>true,
              "glue-distance"=>0,
              "glue-strength"=>"punctuation",
              "case-sensitive"=>true
            }
          ]
        }
      ]
    }


    io = StringIO.new
    p.generate_json(io)
    assert_equal expected, JSON.parse(io.string)
  end
end
