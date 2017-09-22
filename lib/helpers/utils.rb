def json_error(msg="Internal Server Error", status=500)
  Rack::Response.new(
    [{'error': {'status': status, 'message': msg}}.to_json],
    status,
    {'Content-type' => 'application/json'}
  ).finish
end