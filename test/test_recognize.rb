# encoding: utf-8
class TestRecognition < MiniTest::Unit::TestCase
  def test_empty
    assert_route router.add(''),              '/'
  end

  def test_simple1
    assert_route router.add('/'),             '/'
  end

  def test_simple2
    assert_route router.add('/test'),         '/test'
  end

  def test_simple3
    assert_route router.add('/test/one'),     '/test/one'
  end

  def test_simple4
    assert_route router.add('/test/one/two'), '/test/one/two'
  end

  def test_simple5
    assert_route router.add('/test.html'),    '/test.html'
  end

  def test_simple6
    assert_route router.add('/.html'),        '/.html'
  end

  def test_passing
    passed, working = router {
      add('/').to { |env| throw :pass; [200, {}, ['pass']] }
      add('/').to { |env| [200, {}, ['working']] }
    }
    assert_body 'working', router.call(Rack::MockRequest.env_for('/'))
  end

  def test_passing_with_cascade
    passed, working = router {
      add('/').to { |env| [200, {'X-Cascade' => 'pass'}, ['pass']] }
      add('/').to { |env| [200, {}, ['working']] }
    }
    assert_body 'working', router.call(Rack::MockRequest.env_for('/'))
  end

  def test_optional
    route = router {
      add 'one(/two(/three(/four)(/five)))'
    }
    assert_route route, '/one'
    assert_route route, '/one/two'
    assert_route route, '/one/two/three'
    assert_route route, '/one/two/three/four'
    assert_route route, '/one/two/three/five'
    assert_route route, '/one/two/three/four/five'
  end

  def test_escape_paren
    assert_route router.add('/test\(:variable\)'), '/test(hello)', {:variable => 'hello'}
  end

  def test_escape_colon
    assert_route router.add('/test\:variable'), '/test:variable'
  end

  def test_escape_star
    assert_route router.add('/test\*variable'), '/test*variable'
  end

  def test_unicode
    assert_route router.add('/føø'), '/f%C3%B8%C3%B8'
  end

  def test_partial
    router.add("/test*").to { |env| Rack::Response.new(env['PATH_INFO']).finish }
    assert_body '/optional', router.call(Rack::MockRequest.env_for('/test/optional'))
    assert_body '/',         router.call(Rack::MockRequest.env_for('/test'))
  end

  def test_partial_root
    router.add("/*").to { |env| Rack::Response.new(env['PATH_INFO']).finish }
    assert_body '/optional', router.call(Rack::MockRequest.env_for('/optional'))
    assert_body '/',         router.call(Rack::MockRequest.env_for('/'))
  end

  def test_request_mutation
    got_this_far = false
    non_matching, matching = router {
      add("/test/:var/:var2/*glob").matching(:var2 => /123/, :glob => /[a-z]+/).get.arbitrary{|env, params| got_this_far = true; false}
      add("/test/:var/:var2/*glob").matching(:var2 => /123/, :glob => /[a-z]+/).get
    }
    assert_route matching, '/test/123/123/asd/aasd/zxcqwe/asdzxc', {:var => '123', :var2 => '123', :glob => %w{asd aasd zxcqwe asdzxc}}
    assert got_this_far, "matching should have gotten this far"
  end

  def test_multiple_partial
    test, root = router {
      add("/test").partial.to{|env| [200, {}, ['/test',env['PATH_INFO']]]}
      add("/").partial.to{|env| [200, {}, ['/',env['PATH_INFO']]]}
    }
    assert_body ['/test', '/optional'],     router.call(Rack::MockRequest.env_for('/test/optional'))
    assert_body ['/test', '/optional/'],    router.call(Rack::MockRequest.env_for('/test/optional/'))
    assert_body ['/', '/testing/optional'], router.call(Rack::MockRequest.env_for('/testing/optional'))
  end
end
