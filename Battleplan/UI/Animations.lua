-- Fades run as AnimationGroups, which the client drives in C: smooth even
-- when Lua is busy, and no OnUpdate scripts of our own.
local _, ns = ...

local UI = ns.UI

local function alpha(group, from, to, duration, smoothing)
  local a = group:CreateAnimation("Alpha")
  a:SetFromAlpha(from)
  a:SetToAlpha(to)
  a:SetDuration(duration)
  a:SetSmoothing(smoothing)
  group:SetToFinalAlpha(true)
  return a
end

-- Adds frame.fadeIn / frame.fadeOut. Fade-out hides the frame when done.
function UI.AddFade(frame, inSeconds, outSeconds)
  local fadeIn = frame:CreateAnimationGroup()
  alpha(fadeIn, 0, 1, inSeconds or 0.15, "OUT")
  frame.fadeIn = fadeIn

  local fadeOut = frame:CreateAnimationGroup()
  alpha(fadeOut, 1, 0, outSeconds or 0.12, "IN")
  fadeOut:SetScript("OnFinished", function() frame:Hide() end)
  frame.fadeOut = fadeOut
end

function UI.ShowSmooth(frame)
  frame.fadeOut:Stop()
  frame:Show()
  frame.fadeIn:Play()
end

function UI.HideSmooth(frame)
  frame.fadeIn:Stop()
  frame.fadeOut:Play()
end

-- A quick fade-in only (tab switches), with no hide at the end.
function UI.AddPulse(frame, seconds)
  local g = frame:CreateAnimationGroup()
  alpha(g, 0.25, 1, seconds or 0.10, "OUT")
  frame.pulse = g
end
