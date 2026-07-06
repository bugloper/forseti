# frozen_string_literal: true

# Third-party gem integration harness: boots the dummy app, then loads REAL
# optional gems Forseti detects at runtime. Isolated from the main suite
# because once these constants exist, the "gem not present" code paths there
# would never run.
require "spec_helper"
require "secure_headers"
