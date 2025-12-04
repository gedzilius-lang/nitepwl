<template>
  <div>
    <nav>
      <router-link to="/">Feed</router-link>
      <router-link to="/market">Market</router-link>
      <router-link to="/profile">Profile</router-link>
    </nav>
    <main>
      <router-view></router-view>
    </main>
  </div>
</template>
