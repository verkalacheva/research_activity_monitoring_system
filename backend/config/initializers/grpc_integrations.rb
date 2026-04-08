require 'grpc'

$LOAD_PATH.unshift(Rails.root.join('lib').to_s) unless $LOAD_PATH.include?(Rails.root.join('lib').to_s)

require 'grpc_integrations/integrations_pb'
require 'grpc_integrations/integrations_services_pb'
require 'github_check_keys'
