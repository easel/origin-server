ENV["TEST_NAME"] = "functional_domains_controller_test"
require 'test_helper'
class DomiansControllerTest < ActionController::TestCase
  
  def setup
    @controller = DomainsController.new
    
    @random = rand(1000000000)
    @login = "user#{@random}"
    @password = "password"
    @user = CloudUser.new(login: @login)
    @user.capabilities["private_ssl_certificates"] = true
    @user.save
    Lock.create_lock(@user)
    register_user(@login, @password)
    
    @request.env['HTTP_AUTHORIZATION'] = "Basic " + Base64.encode64("#{@login}:#{@password}")
    @request.env['HTTP_ACCEPT'] = "application/json"
    stubber

  end
  
  def teardown
    begin
      @user.force_delete
    rescue
    end
  end
  
  test "domain create show list and destory" do
    namespace = "ns#{@random}"
    post :create, {"name" => namespace}
    assert_response :created

    get :show, {"name" => namespace}
    assert_response :success
    assert json = JSON.parse(response.body)
    assert link = json['data']['links']['ADD_APPLICATION']
    assert_equal Rails.configuration.openshift[:download_cartridges_enabled], link['optional_params'].one?{ |p| p['name'] == 'cartridges[][url]' }

    get :index , {}
    assert_response :success
    new_namespace = "xns#{@random}"
    put :update, {"existing_name" => namespace, "name" => new_namespace}
    assert_response :success
    delete :destroy , {"name" => new_namespace}
    assert_response :ok
  end
  
  
  test "invalid empty or non-existent domain name" do
    post :create, {}
    assert_response :unprocessable_entity
    get :show, {}
    assert_response :not_found
    new_namespace = "xns#{@random}"
    put :update , {"name" => new_namespace}
    assert_response :not_found
    delete :destroy , {}
    assert_response :not_found
    
    get :show, {"name" => "bogus"}
    assert_response :not_found
    new_namespace = "xns#{@random}"
    put :update , {"existing_name" => "bogus", "name" => new_namespace}
    assert_response :not_found
    delete :destroy , {"name" => "bogus"}
    assert_response :not_found
    #try name with a "-"
    namespace = "ns-#{@random}"
    post :create, {"name" => namespace}
    assert_response :unprocessable_entity
    #try name with a "."
    namespace = "ns.#{@random}"
    post :create, {"name" => namespace}
    assert_response :unprocessable_entity
    #try name that exists
    namespace = "ns#{@random}"
    post :create, {"name" => namespace}
    assert_response :created
    post :create, {"name" => namespace}
    assert_response :unprocessable_entity
    
    #try update to invalid name
    put :update , {"existing_name" => namespace, "name" => "ns#{@random}"}
    assert_response :unprocessable_entity
    
    #try more than one domain
    namespace = "ns#{@random}X"
    post :create, {"name" => namespace}
    assert_response :conflict
    
  end
  
  test "delete domain with apps" do
    namespace = "ns#{@random}"
    domain = Domain.new(namespace: namespace, owner:@user)
    domain.save
    
    app_name = "app#{@random}"
    app = Application.create_app(app_name, [PHP_VERSION], domain)
    app.save
    
    delete :destroy , {"name" => namespace}
    assert_response :unprocessable_entity
    
    delete :destroy , {"name" => namespace, "force" => true}
    assert_response :ok
  end
  
  test "update domain with apps" do
    namespace = "ns#{@random}"
    domain = Domain.new(namespace: namespace, owner:@user)
    domain.save
    
    app_name = "app#{@random}"
    app = Application.create_app(app_name, [PHP_VERSION], domain)
    app.save
    
    new_namespace = "xns#{@random}"
    put :update, {"existing_name" => namespace, "name" => new_namespace}
    assert_response :unprocessable_entity
    
    app.destroy_app
    
    put :update, {"existing_name" => namespace, "name" => new_namespace}
    assert_response :success
    get :show, {"name" => new_namespace}
    assert_response :success
  end
end
