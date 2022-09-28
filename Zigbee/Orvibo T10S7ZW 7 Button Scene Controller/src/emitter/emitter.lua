-- Copyright 2022 Bradlee Sutton
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
local build_bind_request = require "st.zigbee.device_management".build_bind_request
local button = require "st.capabilities".button
local switch_level = require "st.capabilities".switchLevel

-- button event map
local button_event_map = {
  [0x00] = "pushed",
  [0x01] = "double",
  [0x02] = "held"
}


-- send device capability event
-- and propagates SmartThings API
-- accordingly.
--
-- @param endpoint           number
-- @param device       ZigbeeDevice
-- @param event        st.capability.attribute_event
-- @param state_change boolean
local function _send_device_event(endpoint, device, event, state_change)
  event.state_change = state_change

  return pcall(
    device.emit_event_for_endpoint,
    device,
    endpoint,
    event)
end


-- handles incoming ZigbeeMessageRx
-- for button-specific events and
-- sends device event accordingly
--
-- @param device ZigbeeDevice
-- @param zbrx   ZigbeeMessageRx
local function send_button_event(_, device, zbrx)
  local endpoint = zbrx.address_header.src_endpoint.value
  local event = tostring(zbrx.body.zcl_body):match("GenericBody:  0(%d)")
  local mapped_evt = button_event_map[tonumber(event)]

  return assert(_send_device_event(
    endpoint,
    device,
    button.button(mapped_evt),
    true)) -- state_change
end


-- send button capability setup
-- to device. Values should be
-- consistent with profile specified
-- by model.
--
-- @param device         ZigbeeDevice
-- @param buttons_number number
-- @param button_events  table
local function send_button_capability_setup(device, buttons_number, button_events)
    assert(_send_device_event(
      1,  -- "main" profile component
      device,
      button.numberOfButtons(buttons_number)))

    -- configure supported values for
    -- each profile component
    for ep=1, buttons_number do
      assert(_send_device_event(
        ep,
        device,
        button.supportedButtonValues(button_events)))
    end
end



-- send ZigbeeMessageRx to device
-- managed by this driver.
--
-- @param device  ZigbeeDevice
-- @param message ZigbeeMessageRx
local function send_zigbee_message(device, message)
  return pcall(
    device.send,
    device,
    message)
end


-- build cluster bind request
--
-- this is supposed to happen as soon
-- as device is created or driver inits.
--
-- @param device         ZigbeeDevice
-- @param hub_zigbee_eui string
-- @param cluster_id     Uint8
local function send_cluster_bind_request(device, hub_zigbee_eui, cluster_id)
  return pcall(
    device.send,
    device,
    build_bind_request(device, cluster_id, hub_zigbee_eui))
end


-- configure reporting of specific
-- cluster attribute.
--
-- this is supposed to happen as soon
-- as device is created or driver inits.
--
-- @param device table
-- @param attr   table
-- @param opts   table
--   example:
--   { min_rep: int, max_rep: int, min_change: int }
local function send_attr_configure_reporting(device, attr, opts)
  return pcall(
    device.send,
    device,
    attr:configure_reporting(device, opts.min_rep, opts.max_rep, opts.min_change))
end


return {
  -- SmartThings-specific events
  send_button_event=send_button_event,
  send_button_capability_setup=send_button_capability_setup,

  -- Zigbee-specific events
  send_zigbee_message=send_zigbee_message,
  send_cluster_bind_request=send_cluster_bind_request,
  send_attr_configure_reporting=send_attr_configure_reporting,
}
