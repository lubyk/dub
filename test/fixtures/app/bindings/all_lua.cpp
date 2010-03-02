#include "matrix.h"

#include "lua_dub_helper.h"


using namespace dub;


/* ============================ Constructors     ====================== */


/** dub::Matrix::Matrix()
 * app/include/matrix.h:14
 */
static int Matrix_Matrix1(lua_State *L) {
  Matrix * retval__    = new Matrix();
  lua_pushclass<Matrix>(L, retval__, "dub.Matrix");
  return 1;
}


/** dub::Matrix::Matrix(int rows, int cols)
 * app/include/matrix.h:16
 */
static int Matrix_Matrix2(lua_State *L) {
  int rows             = luaL_checkint   (L, 1);
  int cols             = luaL_checkint   (L, 2);
  Matrix * retval__    = new Matrix(rows, cols);
  lua_pushclass<Matrix>(L, retval__, "dub.Matrix");
  return 1;
}



/** Overloaded function chooser for Matrix(...) */
static int Matrix_Matrix(lua_State *L) {
  int type__ = lua_type(L, 1);
  if (type__ == LUA_TNUMBER) {
    return Matrix_Matrix2(L);
  } else if (type__ == LUA_TNIL) {
    return Matrix_Matrix1(L);
  } else {
    // use any to raise errors
    return Matrix_Matrix1(L);
  }
}

/* ============================ Destructor       ====================== */

static int Matrix_destructor(lua_State *L) {
  Matrix **userdata = (Matrix**)luaL_checkudata(L, 1, "dub.Matrix");
  if (*userdata) delete *userdata;
  *userdata = NULL;
  return 0;
}

/* ============================ tostring         ====================== */

static int Matrix__tostring(lua_State *L) {
  Matrix **userdata = (Matrix**)luaL_checkudata(L, 1, "dub.Matrix");
  lua_pushfstring(L, "dub.Matrix: %p", *userdata);
  return 1;
}

/* ============================ Member Methods   ====================== */


/** double dub::Matrix::cols()
 * app/include/matrix.h:29
 */
static int Matrix_cols(lua_State *L) {
  Matrix *self__       = *((Matrix**)luaL_checkudata(L, 1, "dub.Matrix"));
  lua_remove(L, 1);
  double retval__      = self__->cols();
  lua_pushnumber(L, retval__);
  return 1;
}


/** double dub::Matrix::rows()
 * app/include/matrix.h:33
 */
static int Matrix_rows(lua_State *L) {
  Matrix *self__       = *((Matrix**)luaL_checkudata(L, 1, "dub.Matrix"));
  lua_remove(L, 1);
  double retval__      = self__->rows();
  lua_pushnumber(L, retval__);
  return 1;
}


/** size_t dub::Matrix::size()
 * app/include/matrix.h:25
 */
static int Matrix_size(lua_State *L) {
  Matrix *self__       = *((Matrix**)luaL_checkudata(L, 1, "dub.Matrix"));
  lua_remove(L, 1);
  size_t retval__      = self__->size();
  lua_pushnumber(L, retval__);
  return 1;
}




/* ============================ Lua Registration ====================== */

static const struct luaL_Reg dub_Matrix_member_methods[] = {
  {"cols"              , Matrix_cols},
  {"rows"              , Matrix_rows},
  {"size"              , Matrix_size},
  {"__tostring"        , Matrix__tostring},
  {"__gc"              , Matrix_destructor},
  {NULL, NULL},
};

static const struct luaL_Reg dub_Matrix_class_methods[] = {
  {"new"               , Matrix_Matrix},
  {NULL, NULL},
};

static void luaopen_dub_Matrix(lua_State *L) {
  // Create the metatable which will contain all the member methods
  luaL_newmetatable(L, "dub.Matrix"); // "dub.Matrix"

  // metatable.__index = metatable (find methods in the table itself)
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "__index");

  // register member methods
  luaL_register(L, NULL, dub_Matrix_member_methods);  // dub_Matrix_member_methods

  // register class methods in a global table like "dub.Matrix"
  luaL_register(L, "dub.Matrix", dub_Matrix_class_methods); // dub_Matrix_class_methods

}
#include "matrix.h"

#include "lua_dub_helper.h"


using namespace dub;


/* ============================ Constructors     ====================== */


/** dub::FloatMat::FloatMat()
 * app/include/matrix.h:54
 */
static int FloatMat_FloatMat1(lua_State *L) {
  FloatMat * retval__  = new FloatMat();
  lua_pushclass<FloatMat>(L, retval__, "dub.FloatMat");
  return 1;
}


/** dub::FloatMat::FloatMat(int rows, int cols)
 * app/include/matrix.h:56
 */
static int FloatMat_FloatMat2(lua_State *L) {
  int rows             = luaL_checkint   (L, 1);
  int cols             = luaL_checkint   (L, 2);
  FloatMat * retval__  = new FloatMat(rows, cols);
  lua_pushclass<FloatMat>(L, retval__, "dub.FloatMat");
  return 1;
}



/** Overloaded function chooser for FloatMat(...) */
static int FloatMat_FloatMat(lua_State *L) {
  int type__ = lua_type(L, 1);
  if (type__ == LUA_TNUMBER) {
    return FloatMat_FloatMat2(L);
  } else if (type__ == LUA_TNIL) {
    return FloatMat_FloatMat1(L);
  } else {
    // use any to raise errors
    return FloatMat_FloatMat1(L);
  }
}

/* ============================ Destructor       ====================== */

static int FloatMat_destructor(lua_State *L) {
  FloatMat **userdata = (FloatMat**)luaL_checkudata(L, 1, "dub.FloatMat");
  if (*userdata) delete *userdata;
  *userdata = NULL;
  return 0;
}

/* ============================ tostring         ====================== */

static int FloatMat__tostring(lua_State *L) {
  FloatMat **userdata = (FloatMat**)luaL_checkudata(L, 1, "dub.FloatMat");
  lua_pushfstring(L, "dub.FloatMat: %p", *userdata);
  return 1;
}

/* ============================ Member Methods   ====================== */


/** size_t dub::FloatMat::cols()
 * app/include/matrix.h:69
 */
static int FloatMat_cols(lua_State *L) {
  FloatMat *self__     = *((FloatMat**)luaL_checkudata(L, 1, "dub.FloatMat"));
  lua_remove(L, 1);
  size_t retval__      = self__->cols();
  lua_pushnumber(L, retval__);
  return 1;
}


/** void dub::FloatMat::fill(T value)
 * app/include/matrix.h:77
 */
static int FloatMat_fill(lua_State *L) {
  FloatMat *self__     = *((FloatMat**)luaL_checkudata(L, 1, "dub.FloatMat"));
  lua_remove(L, 1);
  float value          = luaL_checknumber(L, 1);
  self__->fill(value);
  return 0;
}


/** T dub::FloatMat::get(size_t row, size_t col)
 * app/include/matrix.h:81
 */
static int FloatMat_get(lua_State *L) {
  FloatMat *self__     = *((FloatMat**)luaL_checkudata(L, 1, "dub.FloatMat"));
  lua_remove(L, 1);
  size_t row           = luaL_checknumber(L, 1);
  size_t col           = luaL_checknumber(L, 2);
  float retval__       = self__->get(row, col);
  lua_pushnumber(L, retval__);
  return 1;
}


/** size_t dub::FloatMat::rows()
 * app/include/matrix.h:73
 */
static int FloatMat_rows(lua_State *L) {
  FloatMat *self__     = *((FloatMat**)luaL_checkudata(L, 1, "dub.FloatMat"));
  lua_remove(L, 1);
  size_t retval__      = self__->rows();
  lua_pushnumber(L, retval__);
  return 1;
}


/** size_t dub::FloatMat::size()
 * app/include/matrix.h:65
 */
static int FloatMat_size(lua_State *L) {
  FloatMat *self__     = *((FloatMat**)luaL_checkudata(L, 1, "dub.FloatMat"));
  lua_remove(L, 1);
  size_t retval__      = self__->size();
  lua_pushnumber(L, retval__);
  return 1;
}




/* ============================ Lua Registration ====================== */

static const struct luaL_Reg dub_FloatMat_member_methods[] = {
  {"cols"              , FloatMat_cols},
  {"fill"              , FloatMat_fill},
  {"get"               , FloatMat_get},
  {"rows"              , FloatMat_rows},
  {"size"              , FloatMat_size},
  {"__tostring"        , FloatMat__tostring},
  {"__gc"              , FloatMat_destructor},
  {NULL, NULL},
};

static const struct luaL_Reg dub_FloatMat_class_methods[] = {
  {"new"               , FloatMat_FloatMat},
  {NULL, NULL},
};

static void luaopen_dub_FloatMat(lua_State *L) {
  // Create the metatable which will contain all the member methods
  luaL_newmetatable(L, "dub.FloatMat"); // "dub.Matrix"

  // metatable.__index = metatable (find methods in the table itself)
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "__index");

  // register member methods
  luaL_register(L, NULL, dub_FloatMat_member_methods);  // dub_Matrix_member_methods

  // register class methods in a global table like "dub.Matrix"
  luaL_register(L, "dub.FloatMat", dub_FloatMat_class_methods); // dub_Matrix_class_methods

  luaL_register(L, "dub.FMatrix", dub_FloatMat_class_methods); // typedef

}
