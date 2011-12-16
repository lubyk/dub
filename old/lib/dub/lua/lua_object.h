/*
  ==============================================================================

   This file is part of the LUBYK project (http://lubyk.org)
   Copyright (c) 2007-2011 by Gaspard Bucher (http://teti.ch).

  ------------------------------------------------------------------------------

   Permission is hereby granted, free of charge, to any person obtaining a copy
   of this software and associated documentation files (the "Software"), to deal
   in the Software without restriction, including without limitation the rights
   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
   copies of the Software, and to permit persons to whom the Software is
   furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be included in
   all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
   THE SOFTWARE.

  ==============================================================================
*/
#ifndef INCLUDE_DUB_LUA_OBJECT_H_
#define INCLUDE_DUB_LUA_OBJECT_H_

namespace dub {
/** Calls a lua function back.
 */
class LuaObject
{
public:
  /** Prepare tables to work with the table based self idion.
   * expects stack to be:
   * ... self
   * if self (last argument) is a table, it is used as self. 
   * Otherwise, a new table is created.
   * The method leaves "self" on top of the stack, with self.super = this.
   */
  LuaObject() throw();
  
  int lua_init(lua_State *L, const char *type_name) throw();

  virtual ~LuaObject() {}

  /** The caller should lock before calling this.
   * TODO: The 'const' stuff is stupid: can't we remove it ?
   */
  void pushLuaCallback(const char *method, int len) const;

  lua_State *lua_;

private:

  int thread_in_env_idx_;

  void setupSuper(lua_State *L) throw();
  void setupMetatable(lua_State *L, const char *type_name) throw() ;
  void setupLuaThread(lua_State *L) throw();
};

} // dub

#endif // INCLUDE_DUB_LUA_OBJECT_H_
