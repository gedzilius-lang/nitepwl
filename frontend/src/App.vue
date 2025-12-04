<template>
  <div>
    <nav>
      <router-link to="/">Feed</router-link>
      <router-link to="/market">Market</router-link>
      <router-link to="/profile">Profile</router-link>
      <router-link to="/admin" class="admin-link">Admin</router-link>
    </nav>
    <main>
      <router-view></router-view>
    </main>
  </div>
</template>
<style>
.admin-link { color: #ff4444 !important; margin-left: auto; }
</style>
