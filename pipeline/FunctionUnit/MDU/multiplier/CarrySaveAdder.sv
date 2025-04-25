// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : CarrySaveAdder.sv
// Create  : 2024-03-03 20:57:49
// Revise  : 2024-03-03 21:02:11
// Description :
//   进位保存加法器
// Parameter   :
//   ...
//   ...
// IO Port     :
//   ...
//   ...
// Modification History:
//   Date   |   Author   |   Version   |   Change Description
// -----------------------------------------------------------------------------
// xx-xx-xx |            |     0.1     |    Original Version
// ...
// ==============================================================================


module CarrySaveAdder (
    input a, b, c,
    output carry, s
);
    // rtl实现
    assign carry = a & b | a & c | b & c;
    assign s = a ^ b ^ c;
    // 不知用原语如何，用与非门还是正常的与/或；不知自定义原语如何

endmodule
