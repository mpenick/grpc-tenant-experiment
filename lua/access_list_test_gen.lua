-- File to generate test case arrays of byte integers to avoid solving this problem in lua versions less than 5.3
-- lua access_list_test_gen.lua

function intToBytes(int, numBytes)
	t = {}
    for i = 0, numBytes-1 do
        t[numBytes-i] = (int >> (i * 8)) & 0xFF
    end
    return t
end

gcpTestCases = {27890826298919426, 27890826298921988, 12480470771386372, 51695227282063362, 16376603093237762, 44716867495526402, 23448215215800322, 17548003892920322, 23998550850273282, 16623658211344386, 6791589013094403, 25644193339539458}
for i,testCase in ipairs(gcpTestCases) do
    b = intToBytes(testCase, 8)
    print(string.format("{%d, {%d, %d, %d, %d, %d, %d, %d, %d}},", testCase, b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8]))
end

azureTestCases = {637588574, 637611542, 637538631, 637541551, 637537544, 637553553, 637578577, 637613555, 587299616, 50355713, 536945270, 620796059, 536882271, 536946281, 620851035, 536968208, 620814027, 620763048, 620777048, 50354705}
for i,testCase in ipairs(azureTestCases) do
    b = intToBytes(testCase, 4)
    print(string.format("{%d, {%d, %d, %d, %d}},", testCase, b[1], b[2], b[3], b[4]))
end
