/*
 * Copyright 2021 ConsenSys Software Inc.
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

include "../utils/NativeTypes.dfy"
include "../utils/NonNativeTypes.dfy"
include "../utils/Eth2Types.dfy"
include "../utils/Helpers.dfy"
include "../utils/MathHelpers.dfy"
include "IntSeDes.dfy"
include "BoolSeDes.dfy"
include "BitListSeDes.dfy"
include "BitVectorSeDes.dfy"
include "Constants.dfy"

/**
 *  SSZ library.
 *
 *  Serialise, deserialise
 */
module SSZ {

    import opened NativeTypes
    import opened NonNativeTypes
    import opened Eth2Types
    import opened IntSeDes
    import opened BoolSeDes
    import opened BitListSeDes
    import opened BitVectorSeDes
    import opened Helpers
    import opened Constants  
    import opened MathHelpers  

    /** SizeOf.
     *
     *  @param  s   A serialisable object of type uintN or bool.
     *  @returns    The number of bytes used by a serialised form of this type.
     *
     *  @note       This function needs only to be defined for basic types
     *              i.e. uintN or bool.
     */
    function method sizeOf(s: Serialisable): nat
        requires isBasicTipe(typeOf(s))
        ensures 1 <= sizeOf(s) <= 32 && sizeOf(s) == |serialise(s)|
    {
        match s
            case Bool(_) => 1
            case Uint8(_) => 1  
            case Uint16(_) => 2 
            case Uint32(_) => 4 
            case Uint64(_) => 8
            case Uint128(_) => 16 
            case Uint256(_) => 32
            case Set(s, t, limit) => if |s| > 0 then |s| * sizeOf(s[0]) else 0         // If the set is not empty then the size is the number of elements in the set multiplied by the size of each element
            case Map(m, t, limit) => if |m| > 0 then |m| * (4 + sizeOf(m[0].1)) else 0 // If the map is not empty then the size is the number of elements in the map multiplied by 4 (Map keys are uint32 which is 4 bytes) + the size of the values
    }

    /** default.
     *
     *  @param  t   Serialisable tipe.
     *  @returns    The default serialisable for this tipe.
     *
    */
    function method default(t : Tipe) : Serialisable 
        requires  !(t.Container_? || t.List_? || t.Vector_?)
        requires  t.Bytes_? || t.Bitvector_? ==> 
                match t
                    case Bytes_(n) => n > 0
                    case Bitvector_(n) => n > 0
    {
            match t 
                case Bool_ => Bool(false)
        
                case Uint8_ => Uint8(0)
               
                case Uint16_ => Uint16(0)

                case Uint32_ => Uint32(0)

                case Uint64_ => Uint64(0)

                case Uint128_ => Uint128(0)

                case Uint256_ => Uint256(0)

                case Bitlist_(limit) => Bitlist([],limit)

                case Bitvector_(len) => Bitvector(timeSeq(false,len))

                case Bytes_(len) => Bytes(timeSeq(0,len))

                case Set_(t: Tipe, limit: nat) =>  Set([], t, limit)         // Set has a default value of empty Set 

                case Map_(k: Tipe, v: Tipe, limit: nat) => Map([], t, limit) // Map has a default value of empty Map
    }

    /** Serialise.
     *
     *  @param  s   The object to serialise.
     *  @returns    A sequence of bytes encoding `s`.
     */
    function method serialise(s : Serialisable) : seq<byte> 
        requires  typeOf(s) != Container_
        requires s.List? ==> match s case List(_,t,_) => isBasicTipe(t)
        requires s.Vector? ==> match s case Vector(v) => isBasicTipe(typeOf(v[0]))
        requires s.Set? ==> match s case Set(s,_,_) => (forall i | 0 <= i < |s| :: isBasicTipe(typeOf(s[i]))) &&
                                                       (forall i,j | 0 <= i < |s| && 0 <= j < |s| :: typeOf(s[i]) == typeOf(s[j]))
        requires s.Map? ==> match s case Map(m,t,_) => (forall i, j | 0 <= i < |m| && 0 <= j < |m| && i != j :: m[i].0 != m[j].0) && // Each key is unique
                                                       (forall i | 0 <= i < |m| :: wellTyped(m[i].1)) &&                             // Each value is wellTyped
                                                       (forall i | 0 <= i < |m| :: typeOf(m[i].1) == t) &&                           // The type of each value is t
                                                       (forall i | 0 <= i < |m| :: typeOf(m[i].1) != Container_) &&                  // Values of the Map are not containers
                                                       (forall i | 0 <= i < |m| :: isBasicTipe(typeOf(m[i].1)))                      // The type of each value is BasicTipe
                                
        decreases s
    {
        //  Equalities between upper bounds of uintk types and powers of two 
        constAsPowersOfTwo();

        match s
            case Bool(b) => boolToBytes(b)

            case Uint8(n) =>  uintSe(n as nat, 1)

            case Uint16(n) => uintSe(n as nat, 2)

            case Uint32(n) => uintSe(n as nat, 4)

            case Uint64(n) => uintSe(n as nat, 8)

            case Uint128(n) => uintSe(n as nat, 16)

            case Uint256(n) => uintSe(n as nat, 32)

            case Bitlist(xl,limit) => fromBitlistToBytes(xl)

            case Bitvector(xl) => fromBitvectorToBytes(xl)

            case Bytes(bs) => bs

            case List(l,_,_) => serialiseSeqOfBasics(l)

            case Vector(v) => serialiseSeqOfBasics(v)

            case Set(s, t, limit) => serialiseSeqOfBasics(s) // Serialise the elements of the Set by using serialiseSeqOfBasics
    
            case Map(m, t, limit) => serialiseMap(m)         // Serialise the key and values of the map using custom serialiseMap function    
    } 

    /**
     * Serialise a sequence of basic `Serialisable` values
     * 
     * @param  s Sequence of basic `Serialisable` values
     * @returns  A sequence of bytes encoding `s`.
     */
    function method serialiseSeqOfBasics(s: seq<Serialisable>): seq<byte>
        requires forall i | 0 <= i < |s| :: isBasicTipe(typeOf(s[i]))
        requires forall i,j | 0 <= i < |s| && 0 <= j < |s| :: typeOf(s[i]) == typeOf(s[j])
        ensures |s| == 0 ==> |serialiseSeqOfBasics(s)| == 0
        ensures |s| > 0  ==>|serialiseSeqOfBasics(s)| == |s| * |serialise(s[0])|
        decreases s
    {
        if |s| == 0 then
            []
        else
            serialise(s[0]) + 
            serialiseSeqOfBasics(s[1..])
    }


   /**
    * Serialise a map with uint32 keys and RawSerialisable keys
    * 
    * @param m Sequence of key,value tuple values 
    * @returns A sequence of bytes encoding 'm'
    */
    function method serialiseMap(m: seq<(uint32, RawSerialisable)>): seq<byte>
        requires |m| >= 0                                                                       // Size of Map must be greater than or equal to 0
        ensures |m| == 0 ==> |serialiseMap(m)| == 0                                             // If the Map size is 0 then the output size of serialiseMap() is 0
        ensures |m| > 0 ==> |serialiseMap(m)| > 0                                               // If the Map size is greater than 0 then the output size of serialiseMap() is greater than 0
        requires (forall i, j | 0 <= i < |m| && 0 <= j < |m| && i != j :: m[i].0 != m[j].0)     // Each key in the Map is unique
        requires (forall i | 0 <= i < |m| :: wellTyped(m[i].1))                                 // Each value in the Map is well typed
        requires (forall i | 0 <= i < |m| :: isBasicTipe(typeOf(m[i].1)) && typeOf(m[i].1) != Container_)  // Each value in the Map is BasicType and not a container type
        decreases m
    {
        if |m| == 0 then              
            []
        else 
        var key   := m[0].0;
        var value := m[0].1;
        assert (key as nat) < power2(32);             // Explicitly check that the key is within the allowable range for a 32-bit unsigned integer
        var keyBytes := uintSe(key as nat, 4);        // Serialise key
        var valueBytes := serialise(value);           // Serialise value
        keyBytes + valueBytes + serialiseMap(m[1..])  // Concatenate serialised key and value and recursively do the same for all key value pairs
    }
/*
    /** Deserialise. 
     *  
     *  @param  xs  A sequence of bytes.
     *  @param  s   A target type for the deserialised object.
     *  @returns    Either a Success if `xs` could be deserialised
     *              in an object of type s or a Failure oytherwise.
     *  
     *  @note       It would probabaly be good to return the suffix of `xs`
     *              that has not been used in the deserialisation as well.
     */
     function method deserialise(xs : seq<byte>, s : Tipe) : Try<Serialisable>
        requires !(s.Container_? || s.List_? || s.Vector_?)
        ensures match deserialise(xs, s) 
            case Success(r) => wellTyped(r)
            case Failure => true 
    {
        match s
            case Bool_ => if |xs| == 1 && 0 <= xs[0] <= 1 then
                                var r : Serialisable := Bool(byteToBool(xs));
                                Success(r)
                            else 
                                Failure
                            
            case Uint8_ => if |xs| == 1 then
                                var r : Serialisable := Uint8(uintDes(xs));
                                Success(r)
                             else 
                                Failure

            //  The following cases must check that the result is wellTyped.
            //  If wellTyped and RawSerialisable, the result is a Serialisable.
            case Uint16_ => if |xs| == 2 then
                                //  Verify wellTyped before casting to Serialisable
                                assert(wellTyped(Uint16(uintDes(xs))));
                                //  If wellTyped and RawSerialisable, result is a Serialisable
                                var r : Serialisable := Uint16(uintDes(xs));
                                Success(r)                               
                            else 
                                Failure
            
            case Uint32_ => if |xs| == 4 then
                                assert(wellTyped(Uint32(uintDes(xs))));
                                var r : Serialisable := Uint32(uintDes(xs));
                                Success(r)                               
                            else 
                                Failure

            case Uint64_ => if |xs| == 8 then
                                constAsPowersOfTwo();
                                assert(wellTyped(Uint64(uintDes(xs))));
                                var r : Serialisable := Uint64(uintDes(xs));
                                Success(r)  
                             else 
                                Failure

            case Uint128_ => if |xs| == 16 then
                                constAsPowersOfTwo();
                                assert(wellTyped(Uint128(uintDes(xs))));
                                var r : Serialisable := Uint128(uintDes(xs));
                                Success(r)  
                             else 
                                Failure

            case Uint256_ => if |xs| == 32 then
                                constAsPowersOfTwo();
                                assert(wellTyped(Uint256(uintDes(xs))));
                                var r : Serialisable := Uint256(uintDes(xs));
                                Success(r)                              
                            else 
                                Failure
                                
            case Bitlist_(limit) => if (|xs| >= 1 && xs[|xs| - 1] >= 1) then
                                        var desBl := fromBytesToBitList(xs);
                                        //  Check that the decoded bitlist can fit within limit.
                                        if |desBl| <= limit then
                                            var r : Serialisable := Bitlist(desBl,limit);
                                            Success(r)
                                        else
                                            Failure
                                    else
                                        Failure

            case Bitvector_(len) => if isValidBitVectorEncoding(xs, len) then            
                                        var r : Serialisable := Bitvector(fromBytesToBitVector(xs,len));
                                        Success(r)
                                    else
                                        Failure

            case Bytes_(len) => if 0 < |xs| == len then
                                  var r : Serialisable := Bytes(xs);
                                  Success(r)
                                else Failure
    }

    //  Specifications and Proofs
    
    /** 
     * Well typed deserialisation does not fail. 
     */
    lemma {:induction s} wellTypedDoesNotFail(s : Serialisable) 
        requires !(s.Container? || s.List? || s.Vector?)
        ensures deserialise(serialise(s), typeOf(s)) != Failure 
    {
         match s
            case Bool(b) => 

            case Uint8(n) => 

            case Uint16(n) =>

            case Uint32(n) =>

            case Uint64(n) =>

            case Uint128(n) =>

            case Uint256(n) =>

            case Bitlist(xl,limit) => bitlistDecodeEncodeIsIdentity(xl); 

            case Bitvector(xl) =>

            case Bytes(bs) => 
    }

    /** 
     * Deserialise(serialise(-)) = Identity for well typed objects.
     */
    lemma {:induction s} seDesInvolutive(s : Serialisable) 
        requires !(s.Container? || s.List? || s.Vector?)
        ensures deserialise(serialise(s), typeOf(s)) == Success(s) 
    {   
        //  Proofs on equalities between upper bounds of uintk types and powers of two 
        constAsPowersOfTwo();

        match s 
            case Bitlist(xl,limit) => 
                bitlistDecodeEncodeIsIdentity(xl);

            case Bitvector(xl) =>
                bitvectorDecodeEncodeIsIdentity(xl); 

            case Bool(_) =>  //  Thanks Dafny

            case Uint8(n) => involution(n as nat, 1);

            case Uint16(n) => involution(n as nat, 2);

            case Uint32(n) => involution(n as nat, 4);

            case Uint64(n) => involution(n as nat, 8);

            case Uint128(n) =>  involution(n as nat, 16);

            case Uint256(n) =>  involution(n as nat, 32);

            case Bytes(_) => // Thanks Dafny
    }

    /**
     *  Serialise is injective.
     */
    lemma {:induction s1, s2} serialiseIsInjective(s1: Serialisable, s2 : Serialisable)
        requires !(s1.Container? || s1.List? || s1.Vector?)
        ensures typeOf(s1) == typeOf(s2) ==> 
                    serialise(s1) == serialise(s2) ==> s1 == s2 
    {
        //  The proof follows from involution
        if ( typeOf(s1) ==  typeOf(s2)) {
            if ( serialise(s1) == serialise(s2) ) {
                //  Show that success(s1) == success(s2) which implies s1 == s2
                calc == {
                    Success(s1) ;
                    == { seDesInvolutive(s1); }
                    deserialise(serialise(s1), typeOf(s1));
                    ==
                    deserialise(serialise(s2), typeOf(s2));
                    == { seDesInvolutive(s2); }
                    Success(s2);
                }
            }
        }
    }
    */
}