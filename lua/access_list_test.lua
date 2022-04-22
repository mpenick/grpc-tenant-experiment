-- Test file for access_list functions, bit is only available in lua pre-5.3, so use the following command to run the tests...
-- docker run -it --rm -v "$PWD":/usr/src/myapp -w /usr/src/myapp akorn/luajit:2.1-alpine sh -c "luajit-2.1.0-beta3 access_list_test.lua"
-- TODO: import access_list. Copied code over to avoid dealing with dependencies...
local ffi = require "ffi"

function leftShift(num, shift)
	return num * (2 ^ shift);
end

-- Convert 4 digits into a 32-bit unsigned integer
function bufToUInt32(num1, num2, num3, num4)
	local num = 0;
	num = num + leftShift(num1, 24);
	num = num + leftShift(num2, 16);
	num = num + leftShift(num3, 8);
	num = num + num4;
	return num;
end

-- Convert 8 digits into a 64-bit unsigned integer
function bufToUInt64(num1, num2, num3, num4, num5, num6, num7, num8)
	local num = 0ull;
	num = num + leftShift(num1, 56);
	num = num + leftShift(num2, 48);
	num = num + leftShift(num3, 40);
	num = num + leftShift(num4, 32);
	num = num + leftShift(num5, 24);
	num = num + leftShift(num6, 16);
	num = num + leftShift(num7, 8);
	num = num + num8;
	return num;
end

gcpTestCases = {
    {"27890826298919426", {0, 99, 22, 143, 10, 10, 10, 2}},
    {"27890826298921988", {0, 99, 22, 143, 10, 10, 20, 4}},
    {"12480470771386372", {0, 44, 86, 236, 10, 245, 72, 4}},
    {"51695227282063362", {0, 183, 168, 137, 10, 187, 0, 2}},
    {"16376603093237762", {0, 58, 46, 111, 10, 0, 0, 2}},
    {"44716867495526402", {0, 158, 221, 193, 10, 138, 0, 2}},
    {"23448215215800322", {0, 83, 78, 7, 10, 142, 0, 2}},
    {"17548003892920322", {0, 62, 87, 209, 10, 142, 0, 2}},
    {"23998550850273282", {0, 85, 66, 142, 10, 142, 0, 2}},
    {"16623658211344386", {0, 59, 15, 33, 10, 142, 0, 2}},
    {"6791589013094403", {0, 24, 32, 234, 10, 150, 0, 3}},
    {"25644193339539458", {0, 91, 27, 66, 10, 142, 0, 2}}
}
for i,testCase in ipairs(gcpTestCases) do
    int = testCase[1]
    bytes = testCase[2]
    result = bufToUInt64(bytes[1],bytes[2],bytes[3],bytes[4],bytes[5],bytes[6],bytes[7],bytes[8])
    str_result = string.sub(tostring(ffi.new("uint64_t", result)), 1, -4)
    if int ~= str_result then
        print("FAILURE - AWS test case " .. int .. " did not equal result " .. str_result)
    else
        print("PASS - AWS test case " .. int .. " equals result " .. str_result)
    end
end

azureTestCases = {
    {637588574, {38, 0, 212, 94}},
    {637611542, {38, 1, 46, 22}},
    {637538631, {38, 0, 17, 71}},
    {637541551, {38, 0, 28, 175}},
    {637537544, {38, 0, 13, 8}},
    {637553553, {38, 0, 75, 145}},
    {637578577, {38, 0, 173, 81}},
    {637613555, {38, 1, 53, 243}},
    {587299616, {35, 1, 123, 32}},
    {50355713, {3, 0, 94, 1}},
    {536945270, {32, 1, 34, 118}},
    {620796059, {37, 0, 152, 155}},
    {536882271, {32, 0, 44, 95}},
    {536946281, {32, 1, 38, 105}},
    {620851035, {37, 1, 111, 91}},
    {536968208, {32, 1, 124, 16}},
    {620814027, {37, 0, 222, 203}},
    {620763048, {37, 0, 23, 168}},
    {620777048, {37, 0, 78, 88}},
    {50354705, {3, 0, 90, 17}}
}
for i,testCase in ipairs(azureTestCases) do
    int = testCase[1]
    bytes = testCase[2]
    result = bufToUInt32(bytes[1],bytes[2],bytes[3],bytes[4])
    if string.format("%d", int) ~= string.format("%d", result) then
        print("FAILURE - Azure test case " .. string.format("%d", int) .. " did not equal result " .. string.format("%d", result))
    else
        print("PASS - Azure test case " .. string.format("%d", int) .. " equals result " .. string.format("%d", result))
    end
end
