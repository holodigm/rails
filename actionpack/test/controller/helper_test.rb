require 'abstract_unit'

ActionController::Base.helpers_path = File.expand_path('../../fixtures/helpers', __FILE__)

module Fun
  class GamesController < ActionController::Base
    def render_hello_world
      render :inline => "hello: <%= stratego %>"
    end

    def rescue_action(e) raise end
  end

  class PdfController < ActionController::Base
    def test
      render :inline => "test: <%= foobar %>"
    end

    def rescue_action(e) raise end
  end
end

class AllHelpersController < ActionController::Base
  helper :all
end

module ImpressiveLibrary
  extend ActiveSupport::Concern
  included do
    helper_method :useful_function
  end

  def useful_function() end
end

ActionController::Base.send :include, ImpressiveLibrary

class JustMeController < ActionController::Base
  clear_helpers

  def flash
    render :inline => "<h1><%= notice %></h1>"
  end

  def lib
    render :inline => '<%= useful_function %>'
  end
end

class MeTooController < JustMeController
end

module LocalAbcHelper
  def a() end
  def b() end
  def c() end
end

class HelperTest < ActiveSupport::TestCase
  class TestController < ActionController::Base
    attr_accessor :delegate_attr
    def delegate_method() end
    def rescue_action(e) raise end
  end

  def setup
    # Increment symbol counter.
    @symbol = (@@counter ||= 'A0').succ!.dup

    # Generate new controller class.
    controller_class_name = "Helper#{@symbol}Controller"
    eval("class #{controller_class_name} < TestController; end")
    @controller_class = self.class.const_get(controller_class_name)

    # Set default test helper.
    self.test_helper = LocalAbcHelper
  end

  def test_helper
    assert_equal expected_helper_methods, missing_methods
    assert_nothing_raised { @controller_class.helper TestHelper }
    assert_equal [], missing_methods
  end

  def test_helper_method
    assert_nothing_raised { @controller_class.helper_method :delegate_method }
    assert master_helper_methods.include?('delegate_method')
  end

  def test_helper_attr
    assert_nothing_raised { @controller_class.helper_attr :delegate_attr }
    assert master_helper_methods.include?('delegate_attr')
    assert master_helper_methods.include?('delegate_attr=')
  end

  def call_controller(klass, action)
    request  = ActionController::TestRequest.new
    klass.action(action).call(request.env)
  end

  def test_helper_for_nested_controller
    assert_equal 'hello: Iz guuut!',
      call_controller(Fun::GamesController, "render_hello_world").last.body
    # request  = ActionController::TestRequest.new
    #
    # resp = Fun::GamesController.action(:render_hello_world).call(request.env)
    # assert_equal 'hello: Iz guuut!', resp.last.body
  end

  def test_helper_for_acronym_controller
    assert_equal "test: baz", call_controller(Fun::PdfController, "test").last.body
    #
    # request  = ActionController::TestRequest.new
    # response = ActionController::TestResponse.new
    # request.action = 'test'
    #
    # assert_equal 'test: baz', Fun::PdfController.process(request, response).body
  end

  def test_default_helpers_only
    assert_equal [JustMeHelper], JustMeController._helpers.ancestors.reject(&:anonymous?)
    assert_equal [MeTooHelper, JustMeHelper], MeTooController._helpers.ancestors.reject(&:anonymous?)
  end

  def test_base_helper_methods_after_clear_helpers
    assert_nothing_raised do
      call_controller(JustMeController, "flash")
    end
  end

  def test_lib_helper_methods_after_clear_helpers
    assert_nothing_raised do
      call_controller(JustMeController, "lib")
    end
  end

  def test_all_helpers
    methods = AllHelpersController._helpers.instance_methods.map {|m| m.to_s}

    # abc_helper.rb
    assert methods.include?('bare_a')

    # fun/games_helper.rb
    assert methods.include?('stratego')

    # fun/pdf_helper.rb
    assert methods.include?('foobar')
  end

  def test_all_helpers_with_alternate_helper_dir
    @controller_class.helpers_path = File.expand_path('../../fixtures/alternate_helpers', __FILE__)

    # Reload helpers
    @controller_class._helpers = Module.new
    @controller_class.helper :all

    # helpers/abc_helper.rb should not be included
    assert !master_helper_methods.include?('bare_a')

    # alternate_helpers/foo_helper.rb
    assert master_helper_methods.include?('baz')
  end

  def test_helper_proxy
    methods = AllHelpersController.helpers.methods.map(&:to_s)

    # Action View
    assert methods.include?('pluralize')

    # abc_helper.rb
    assert methods.include?('bare_a')

    # fun/games_helper.rb
    assert methods.include?('stratego')

    # fun/pdf_helper.rb
    assert methods.include?('foobar')
  end

  private
    def expected_helper_methods
      TestHelper.instance_methods.map {|m| m.to_s }
    end

    def master_helper_methods
      @controller_class._helpers.instance_methods.map {|m| m.to_s }
    end

    def missing_methods
      expected_helper_methods - master_helper_methods
    end

    def test_helper=(helper_module)
      silence_warnings { self.class.const_set('TestHelper', helper_module) }
    end
end


class IsolatedHelpersTest < ActiveSupport::TestCase
  class A < ActionController::Base
    def index
      render :inline => '<%= shout %>'
    end

    def rescue_action(e) raise end
  end

  class B < A
    helper { def shout; 'B' end }

    def index
      render :inline => '<%= shout %>'
    end
  end

  class C < A
    helper { def shout; 'C' end }

    def index
      render :inline => '<%= shout %>'
    end
  end

  def call_controller(klass, action)
    request  = ActionController::TestRequest.new
    klass.action(action).call(request.env)
  end

  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @request.action = 'index'
  end

  def test_helper_in_a
    assert_raise(ActionView::Template::Error) { call_controller(A, "index") }
  end

  def test_helper_in_b
    assert_equal 'B', call_controller(B, "index").last.body
  end

  def test_helper_in_c
    assert_equal 'C', call_controller(C, "index").last.body
  end
end
