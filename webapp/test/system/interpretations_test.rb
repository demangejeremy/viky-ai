require 'application_system_test_case'

class InterpretationsTest < ApplicationSystemTestCase

  test 'navigation' do
    go_to_agents_index
    assert page.has_text?('admin/weather')
    click_link 'My awesome weather bot admin/weather'
    assert page.has_text?('weather_greeting')

    click_link 'weather_greeting'
    assert page.has_text?('weather_greeting PUBLIC (admin/weather/weather_greeting)')
  end


  test 'Show an interpretation with details' do
    login_as 'show_on_agent_weather@viky.ai', 'BimBamBoom'
    assert page.has_text?('admin/weather')
    click_link 'My awesome weather bot admin/weather'
    assert page.has_text?('weather_greeting')

    click_link 'weather_greeting'
    assert page.has_text?('weather_greeting (admin/weather/weather_greeting)')
    within('#interpretations-list') do
      click_link 'Hello world'
      assert page.has_text?('Cancel')
      assert page.has_no_button?('Update')
      assert page.has_no_link?('Delete')
      assert page.has_no_field?('trix-editor')
      assert page.has_no_field?("input[name*='aliasname']")
    end
  end


  test 'Create an interpretation' do
    admin_go_to_intent_show(agents(:weather), intents(:weather_greeting))

    assert_equal "1", first('#current-locale-tab-badge').text

    first('trix-editor').click.set('Good morning')
    click_button 'Add'
    assert page.has_text?('Good morning')

    assert_equal "2", first('#current-locale-tab-badge').text
  end


  test 'Create an interpretation with alias' do
    admin_go_to_intent_show(agents(:weather), intents(:weather_greeting))

    assert_equal 1, all('.interpretation-resume').count
    assert_equal "world", first('.interpretation-resume__alias-blue').text

    first('trix-editor').click.set('Salut Marcel')
    select_text_in_trix("trix-editor", 6, 12)
    find_link('admin/weather/weather_who').click

    within('.aliases') do
      assert page.has_link?('admin/weather/weather_who')
      assert page.has_text?('Marcel')
    end

    click_button 'Add'

    assert page.has_text?('Salut Marcel')
    assert_equal 2, all('.interpretation-resume').count
    assert_equal "Marcel", first('.interpretation-resume__alias-blue').text
  end


  test 'Create an interpretation with digits' do
    admin_go_to_intent_show(agents(:weather), intents(:weather_greeting))

    assert_equal 1, all('.interpretation-resume').count
    assert_equal "world", first('.interpretation-resume__alias-blue').text

    first('trix-editor').click.set("Le 01/01/2018 j'achète de l'Aspirine")
    select_text_in_trix("trix-editor", 3, 5)
    find_link('Digit').click

    select_text_in_trix("trix-editor", 6, 8)
    find_link('Digit').click

    select_text_in_trix("trix-editor", 9, 13)
    find_link('Digit').click

    within('.aliases') do
      inputs = all("input[name*='aliasname']")
      inputs[0].set('day')
      inputs[1].set('month')
      inputs[2].set('year')
    end

    click_button 'Add'
    assert page.has_text?("Le 01/01/2018 j'achète de l'Aspirine")

    assert_equal 2, all('.interpretation-resume').count
    expected = ["01", "01", "2018"]
    assert_equal expected, all('.interpretation-resume__alias-black').collect(&:text)

    click_link "Le 01/01/2018 j'achète de l'Aspirine"
    assert page.has_text?('Cancel')
    within('.aliases') do
      expected = ["day", "month", "year"]
      assert_equal expected, all("input[name*='aliasname']").collect(&:value)
    end
  end


  test 'Errors on interpretation creation' do
    admin_go_to_intent_show(agents(:weather), intents(:weather_greeting))

    assert_equal "1", first('#current-locale-tab-badge').text

    first('trix-editor').click.set('')
    click_button 'Add'
    assert page.has_text?('Expression can\'t be blank')

    assert_equal "1", first('#current-locale-tab-badge').text
  end


  test 'Errors on interpretation creation with alias' do
    admin_go_to_intent_show(agents(:weather), intents(:weather_greeting))

    assert_equal 1, all('.interpretation-resume').count
    assert_equal "world", first('.interpretation-resume__alias-blue').text

    first('trix-editor').click.set('Salut Marcel')
    select_text_in_trix("trix-editor", 6, 12)
    find_link('admin/weather/weather_who').click

    within('.aliases') do
      assert page.has_text?('admin/weather/weather_who')
      assert page.has_text?('Marcel')
      first('input').set("")
    end

    click_button 'Add'
    assert page.has_text?("Parameter name can't be blank")
  end


  test 'Update an interpretation (simple)' do
    admin_go_to_intent_show(agents(:weather), intents(:weather_greeting))

    within('.interpretation-new-form-container') do
      click_link 'fr'
    end
    assert page.has_link?('Bonjour tout le monde')

    assert_equal '1', first('#current-locale-tab-badge').text

    within('#interpretations-list') do
      click_link 'Bonjour tout le monde'
      assert page.has_text?('Cancel')
      first('trix-editor').click.set('Salut à tous')
      check('interpretation[keep_order]')
      check('interpretation[glued]')
      uncheck('interpretation[auto_solution_enabled]')
      fill_in_editor_field '10'
      click_button 'Update'
    end

    assert page.has_link?('Salut à tous')
    assert_equal '1', first('#current-locale-tab-badge').text
  end


  test 'Update an interpretation (add alias)' do
    admin_go_to_intent_show(agents(:weather), intents(:weather_greeting))

    within('.interpretation-new-form-container') do
      click_link 'en'
    end

    assert page.has_link?('Hello world')

    within('#interpretations-list') do
      click_link 'Hello world'
      assert page.has_text?('Cancel')

      select_text_in_trix("#interpretations-list trix-editor", 0, 5)
    end

    within('#popup-add-tag') do
      find_link('admin/weather/weather_who').click
    end

    within('#interpretations-list') do
      within('.aliases') do
        assert page.has_text?('Hello')
        all("input[name*='is_list']").first.click
      end

      click_button 'Update'
    end

    assert page.has_link?('Hello world')
    assert_equal 1, all('.interpretation-resume').count
    assert_equal ["Hello", "world"], all('.interpretation-resume__alias-blue').collect(&:text)

    within('#interpretations-list') do
      click_link 'Hello world'
      assert page.has_text?('Cancel')
      assert all("input[name*='is_list']")[0].checked?
      assert !all("input[name*='is_list']")[1].checked?
    end
  end


  test 'Update an interpretation (remove alias)' do
    admin_go_to_intent_show(agents(:weather), intents(:weather_greeting))

    within('.interpretation-new-form-container') do
      click_link 'en'
    end

    assert page.has_link?('Hello world')

    within('#interpretations-list') do
      click_link 'Hello world'
      assert page.has_text?('Cancel')

      select_text_in_trix("#interpretations-list trix-editor", 6, 10)
    end
    find_link('Remove annotation(s)').click
    click_button 'Update'

    assert page.has_link?('Hello world')
    assert_equal 0, all('.interpretation-resume').count
  end


  test 'Remove alias from summary board' do
    admin_go_to_intent_show(agents(:weather), intents(:weather_greeting))

    within('.interpretation-new-form-container') do
      click_link 'en'
    end

    assert page.has_link?('Hello world')

    within('#interpretations-list') do
      click_link 'Hello world'
      within('.aliases') do
        assert page.has_text?('who')
        all('a[href="#"').last.click
        assert page.has_no_text?('who')
      end
      who = interpretation_aliases(:weather_greeting_hello_who)
      assert_no_text_selected_in_trix who.interpretation.id, who.aliasname
      click_button 'Update'
    end

    assert page.has_link?('Hello world')
    assert_equal 0, all('.interpretation-resume').count
  end


  test 'Update an interpretation and cancel' do
    admin_go_to_intent_show(agents(:weather), intents(:weather_greeting))

    within('.interpretation-new-form-container') do
      click_link 'en'
    end

    assert page.has_link?('Hello world')
    within('#interpretations-list') do
      click_link 'Hello world'
      assert page.has_text?('Cancel')
      click_link('Cancel')
    end
    assert page.has_link?('Hello world')
  end


  test 'change locale via drag & drop' do
    admin_go_to_intent_show(agents(:weather), intents(:weather_greeting))

    expected = ["en 1", "fr 1", "+"]
    assert_equal expected, all(".tabs ul li").collect(&:text)

    # Does not works...

    # source = first('#interpretations-list .interpretations-list__draggable')
    # target = first('.tabs li.js-draggable-locale')
    # source.drag_to(target)

    # expected = ["en 0", "fr 2", "+"]
    # assert_equal expected, all(".tabs ul li").collect(&:text)
  end


  test 'Delete an interpretation' do
    admin_go_to_intent_show(agents(:weather), intents(:weather_greeting))

    assert page.has_link?('Hello world')

    assert_equal "1", first('#current-locale-tab-badge').text

    within('#interpretations-list') do
      click_link 'Hello world'
      assert page.has_text?('Cancel')
      all('a').last.click
    end
    assert page.has_no_link?('Cancel')
    assert_equal "0", first('#current-locale-tab-badge').text
  end


  private

    def admin_go_to_intent_show(agent, intent)
      admin_login
      visit user_agent_intent_path(users(:admin), agent, intent)
      assert page.has_text?("#{intent.intentname} PUBLIC (#{users(:admin).username}/#{agent.agentname}/#{intent.intentname})")
    end

    def fill_in_editor_field(text)
      within '.CodeMirror' do
        # Click makes CodeMirror element active:
        current_scope.click
        # Find the hidden textarea:
        field = current_scope.find('textarea', visible: false)
        # Mimic user typing the text:
        field.send_keys text
      end
    end
end
