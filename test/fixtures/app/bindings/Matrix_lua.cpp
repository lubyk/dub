#include "matrix.h"

#include "lua_doxy_helper.h"


using namespace doxy;


/* ============================ Constructors     ====================== */


/** doxy::Matrix::Matrix()
 * app/include/matrix.h:14
 */
static int Matrix_Matrix1(lua_State *L) {
  Matrix * retval__    = new Matrix();
  lua_pushclass<Matrix>(L, retval__, "doxy.Matrix");
  return 1;
}


/** doxy::Matrix::Matrix(int rows, int cols)
 * app/include/matrix.h:16
 */
static int Matrix_Matrix2(lua_State *L) {
  int rows             = luaL_checkint   (L, 1);
  int cols             = luaL_checkint   (L, 2);
  Matrix * retval__    = new Matrix(rows, cols);
  lua_pushclass<Matrix>(L, retval__, "doxy.Matrix");
  return 1;
}



/** Overloaded function chooser for Matrix(...) */
static int Matrix_Matrix(lua_State *L) {
  int type__ = lua_type(L, 1);
  if (type__ == LUA_TNIL) {
    return Matrix_Matrix1(L);
  } else if (type__ == LUA_TNUMBER) {
    return Matrix_Matrix2(L);
  } else {
    // use any to raise errors
    return Matrix_Matrix2(L);
  }
}

/* ============================ Destructor       ====================== */

static int Matrix_destructor(lua_State *L) {
  Matrix **userdata = (Matrix**)luaL_checkudata(L, 1, "doxy.Matrix");
  if (*userdata) delete *userdata;
  *userdata = NULL;
  return 0;
}

/* ============================ Member Methods   ====================== */


/** double doxy::Matrix::cols()
 * app/include/matrix.h:29
 */
static int Matrix_cols(lua_State *L) {
  Matrix *self__       = *((Matrix**)luaL_checkudata(L, 1, "doxy.Matrix"));
  lua_remove(L, 1);
  double retval__      = self__->cols();
  lua_pushnumber(L, retval__);
  return 1;
}


/** double doxy::Matrix::rows()
 * app/include/matrix.h:33
 */
static int Matrix_rows(lua_State *L) {
  Matrix *self__       = *((Matrix**)luaL_checkudata(L, 1, "doxy.Matrix"));
  lua_remove(L, 1);
  double retval__      = self__->rows();
  lua_pushnumber(L, retval__);
  return 1;
}


/** size_t doxy::Matrix::size()
 * app/include/matrix.h:25
 */
static int Matrix_size(lua_State *L) {
  Matrix *self__       = *((Matrix**)luaL_checkudata(L, 1, "doxy.Matrix"));
  lua_remove(L, 1);
  size_t retval__      = self__->size();
  lua_pushnumber(L, retval__);
  return 1;
}




/* ============================ Lua Registration ====================== */

static const struct luaL_Reg doxy_Matrix_member_methods[] = {
  {"cols"              , Matrix_cols},
  {"rows"              , Matrix_rows},
  {"size"              , Matrix_size},
  {"__gc"              , Matrix_destructor},
  {NULL, NULL},
};

static const struct luaL_Reg doxy_Matrix_class_methods[] = {
  {"new"               , Matrix_Matrix},
  {NULL, NULL},
};

static void luaopen_doxy_Matrix(lua_State *L) {
  // Create the metatable which will contain all the member methods
  luaL_newmetatable(L, "doxy.Matrix"); // "cv.Mat"

  // metatable.__index = metatable (find methods in the table itself)
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "__index");

  // register member methods
  luaL_register(L, NULL, doxy_Matrix_member_methods);  // cv_Mat_member_methods

  // register class methods in a global table like "cv.Mat"
  luaL_register(L, "doxy.Matrix", doxy_Matrix_class_methods); // cv_Mat_class_methods
}
