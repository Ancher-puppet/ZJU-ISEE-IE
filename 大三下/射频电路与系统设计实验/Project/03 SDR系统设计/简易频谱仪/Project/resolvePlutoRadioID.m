function radioID = resolvePlutoRadioID()
%RESOLVEPLUTORADIOID Return the first detected Pluto RadioID.

devices = findPlutoRadio;
if isempty(devices)
    error("No Pluto radio detected. Please reconnect the device and try again.");
end

if isstruct(devices)
    radioID = string(devices(1).RadioID);
elseif iscell(devices)
    radioID = string(devices{1}.RadioID);
else
    radioID = string(devices(1).RadioID);
end

if strlength(radioID) == 0
    radioID = "usb:0";
end
end
