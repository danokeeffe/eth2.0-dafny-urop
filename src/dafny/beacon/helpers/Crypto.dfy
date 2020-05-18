/*
 * Copyright 2020 ConsenSys AG.
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may
 * not use this file except in compliance with the License. You may obtain
 * a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software dis-
 * tributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations
 * under the License.
 */

include "../../utils/Helpers.dfy"
include "../../utils/Eth2Types.dfy"

module {:extern "eth2crypto"} Crypto {
    import opened Eth2Types
    import opened NativeTypes

    /**
     * Calculate the SHA256 of a sequence of bytes
     * 
     * @param data Sequence of bytes
     * 
     * @returns SHA256 hash of `data`
     */
    function method {:extern} hash(data:seq<Byte>) : hash32
}