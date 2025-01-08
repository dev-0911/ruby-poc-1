class DashboardsController < ApplicationController
  def index
  end
end

# Loading hooks to tweak features in sandbox mode.
ActiveSupport.run_load_hooks(:dashboards_controller)
